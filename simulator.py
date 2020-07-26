import pygame
import random
from random import uniform
import uuid
import math
from pygame import gfxdraw
from datetime import datetime
import socketio
from pymongo import MongoClient
import json
import threading, queue
import external
FPS = 120 #frames per second setting
fpsClock = pygame.time.Clock()

#pymongo
client = MongoClient()
db = client.waldo
persons_col = db.persons
cross_col = db.cross_persons

x = 40
y = 40
import os
os.environ['SDL_VIDEO_WINDOW_POS'] = "%d,%d" % (x,y)


sio = socketio.Client()

@sio.event
def connect():
    print('connection established')


@sio.event
def disconnect():
    print('disconnected from server')

sio.connect('http://localhost:8765')

pygame.init()

canvasWidth = 600
canvasHeight = 300
win = pygame.display.set_mode((canvasWidth,canvasHeight))
pygame.display.set_caption("Contact tracing")

font = pygame.font.SysFont("arial", 20)
font2 = pygame.font.SysFont("arial", 14)
q = queue.Queue()
def worker():
    while True:
        item, args = q.get()
        item(*args)

threading.Thread(target=worker, daemon=True).start()

def uid(): return str(uuid.uuid1())

def gColor(b):
    if(b): return (255,153,0)
    return (42,193,166)

class Segment:
    def __init__(self):
        self.x = 0
        self.y = 0
        self.width = 0 
        self.height = 0 

class AreaInfection:
    def __init__(self):
        self.id=uid()
        self.x=0
        self.y=0
        self.r=5
        self.hasCovid=True
probCovid  = 0.2
distanceInfection = 1*10
circles = []
circle = dict()
radius=4
overlapping = False
NumCircles = 0
protection = 500
counter = 0
infecteds = []



class PersonInput:
    def __init__(self):
        self.HDZ_RATE = 0.75
        self.VDZ_RATE = 0.65
        self.WM_RATE = 0.85
        self.SS_RATE = 0.15
        self.ML_RATE = 0.78

        self.history_graph_range =(1,10)
        self.time_last_g_range  =(0,10)
        self.ratio  =(0,5)
        self.cross  =(0,5)

        self.history_graph = 1
        self.time_last_g = 10
        self.visit_danger_zone=False
        self.massive_location=False
        self.cross_covid=0
        self.hasCovid=False

        self.search_synt=False
        self.work_public_area_medicine=False
        self.home_danger_zone = False
        self.rate = 0
    
    def make_rate(self, value, rang):
        return ((value-rang[0])*100)/(rang[1]-rang[0])/100
    def calculate_rate(self):
        history_graph_rate = self.make_rate(self.history_graph, self.history_graph_range)
        time_last_g_rate = 1 - self.make_rate(self.time_last_g, self.time_last_g_range)
        home_danger_zone_rate = ( 1 if self.home_danger_zone else 0 ) * self.HDZ_RATE
        visit_danger_zone_rate = ( 1 if self.visit_danger_zone else 0 ) * self.VDZ_RATE
        work_public_area_medicine_rate = ( 1 if self.work_public_area_medicine else 0 ) * self.WM_RATE
        massive_location_rate = (1 if self.massive_location else 0) * self.ML_RATE
        cross_covid_rate = ( 1 - 1/(self.cross_covid*2)) if self.cross_covid>0 else 0
        search_synt_rate = (1 if self.search_synt else 0) * self.SS_RATE
        ss = history_graph_rate + time_last_g_rate + home_danger_zone_rate + visit_danger_zone_rate + work_public_area_medicine_rate + \
            massive_location_rate + cross_covid_rate + search_synt_rate
        self.rate =  self.make_rate(ss, self.ratio)
        return self.rate
class Person:
    def __init__(self, _id):
        self.id=_id
        self.x=uniform(0,canvasWidth) + radius
        self.y=uniform(0,canvasHeight) + radius
        self.r=radius
        self.hasCovid=False
        self.xVel= uniform(-1,1)
        self.yVel= uniform(-1,1)
        self.ratioMove= uniform(0,0.1)
        self.radians=  uniform(0,1) * math.pi * 2
        self.hasLink=False
        self.tracing = []
        self.nearElems = []
        self.probInfection = 0.03
        self.input = PersonInput()
        self.me = False
        self.lastSegment = None
    def draw(self):
       
        if(self.hasCovid):
            pygame.gfxdraw.circle(win, int(self.x), int(self.y) , radius+distanceInfection, gColor(self.hasCovid))
            pygame.gfxdraw.filled_circle(win, int(self.x), int(self.y) , radius, (255,0,0))
        else:
            if(self.me):
                pygame.gfxdraw.filled_circle(win, int(self.x), int(self.y) , radius+3,  (250,153,70))
            else:
                pygame.gfxdraw.filled_circle(win, int(self.x), int(self.y) , radius, gColor(self.hasCovid))

    def collision(self, ext):

        for index, seg in enumerate(listSegments):
            if seg.x <= self.x and self.x <= (seg.x+seg.width) and seg.y <= self.y and self.y <= (seg.y+seg.height) :
                if self.lastSegment and self.lastSegment != index:
                    if self.input.history_graph  <= 5:
                        self.input.history_graph += 1
                self.lastSegment = index

        p_infection = external.prob(self.probInfection)
        distance = external.distance(ext.x, ext.y,self.x, self.y)
        if type(ext).__name__ == 'Person' and  distance < 200:
            self.nearElems.append(ext)
            if ext.input.rate > 0.6 or ext.hasCovid:
                self.input.cross_covid += 1
            pygame.draw.line(win, (20,10,120), (self.x,self.y), (ext.x,ext.y), 2)

        minDist = ext.r + self.r + distanceInfection
        if ext.hasCovid and distance < minDist and p_infection:
            q.put( (cross_col.update, [{"uuid":uid(),"current_id":self.id, "target_id":ext.id},{"last_cross":datetime.now(),"current_id":self.id, "target_id":ext.id}, True] ) )
            return True

        if not self.hasCovid:
            for g in ext.tracing:
                distanceTracing = external.distance(g.x, g.y,self.x, self.y)
                minDist = g.r
                if distanceTracing < minDist and p_infection :
                    self.input.visit_danger_zone = 1
                    return False



    def trails(self):
        rad = self.r*7
        if self.hasCovid:
            inf = AreaInfection()
            inf.x = self.x
            inf.y = self.y
            inf.r = rad
            if external.prob(0.009):
                self.tracing.append(inf)
            if len(self.tracing) > 2:
                self.tracing.pop(0)
            for f in self.tracing:
                pygame.gfxdraw.circle(win, int(f.x), int(f.y) , rad, (244,20,20))

#while(len(circles) < NumCircles and counter < protection):
#    person = Person()
#    if(external.prob(probCovid)):
#        person.hasCovid = True
#    overlapping = False
#    for existing in circles:
#        d = external.distance(person.x, person.y, existing.x, existing.y)
#        if d < person.r + existing.r or \
#                (person.x < ( radius+10) or \
#                    person.x + radius+10> canvasWidth) or \
#                        (person.y < ( radius+10) or \
#                            person.y + radius+10> canvasHeight) :
#            overlapping = True
#            break
#    
#    if not overlapping:
#        circles.append(person)
#    counter+=1

fop = Person(999)

fop.input.history_graph = 1# random.randint(1,10) #algorithm
fop.input.time_last_g = 0#random.randint(0,10) #algorithm
#fop.input.visit_danger_zone = random.randint(0,1) #algorithm
#fop.input.cross_covid = random.randint(0,5) #algorithm

fop.input.home_danger_zone = random.randint(0,1) #input
#fop.input.work_public_area_medicine = random.randint(0,1) #algorithm
fop.input.search_synt = random.randint(0,1) #algorithm
circles.append(fop)


inf = AreaInfection()
inf.x = 20
inf.y = 80
inf.r = 12
fop.tracing.append(inf)

def update():
    global circles
    global fop
    global modeMove
    Mouse_x, Mouse_y = pygame.mouse.get_pos()

    fop.x = Mouse_x if modeMove else (canvasWidth/2  ) - 20
    fop.y =  Mouse_y if modeMove else (canvasHeight/2 ) - 20
    fop.r = 9
    fop.me =True
    fop.draw()
    fop.input.cross_covid = 0

    if len(fop.nearElems) > 3:
        fop.input.massive_location = True
    else:
        fop.input.massive_location = False
    
    fps = font.render("Input:" + str(round(fop.input.calculate_rate(),2)), True, pygame.Color('white'))
    win.blit(fps, (fop.x, fop.y))

   
    pygame.gfxdraw.circle(win, 40, 100 , 20, (244,20,20))

    for t in circles:
        #t.trails()
        t.nearElems = []


           # q.put( (persons_col.update, [{'id':t.id},{"$push" : {"location":{"x":t.x, "y":t.y}}}, True] ) )
        for ext in circles:
            if t.collision(ext):
                t.hasCovid=True

                    
        #t.radians += t.ratioMove / math.pi
        #t.x = t.x +  math.sin(t.radians) * t.xVel * math.sin(uniform(1,2))
        #t.y = t.y +  math.cos(t.radians) * t.yVel * math.sin(uniform(1,2))
        #if(t.x < (0 + radius) or t.x + radius> canvasWidth):
        #    t.xVel = -t.xVel
        #if(t.y< (0 + radius) or t.y + radius>= canvasHeight):
        #    t.yVel = -t.yVel

        
        t.draw()


def redrawGameWindow():
    pygame.display.flip() 

run = True
CURRENT_DAYS = 0
PASS_DAYS = 0
CURRENT_PERSON=1
modeMove= False
probs = []

SEGMENTS = (3,2)
listSegments = []
while run:

    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            run = False
       
        if event.type == pygame.KEYDOWN:
            

            if event.key==pygame.K_r:
                c = random.choice(circles)
                sio.emit('calculate', {"calculate":201, "index":c.id})
                c.hasCovid = True
            if event.key==pygame.K_h:
                sio.emit('calculate', {"calculate":202})

            if event.key==pygame.K_m:
                modeMove = True
            if event.key==pygame.K_n:
                modeMove = False
                Mouse_x, Mouse_y = pygame.mouse.get_pos()
                fop.x = Mouse_x
                fop.y = Mouse_y

            if event.key==pygame.K_p:
                run = False
            if event.key==pygame.K_c:
                sio.emit('calculate', {"calculate":fop.input.calculate_rate()})
            if event.key==pygame.K_x:
                redrawGameWindow()
                circles=[]
                fop.hasCovid = False
                modeMove = False
                PASS_DAYS=0
                CURRENT_DAYS = 0
                CURRENT_PERSON=1
                fop.x = canvasWidth/2
                fop.y = canvasHeight/2
                fop.me = True
                fop.r = 9
                fop.input.cross_covid = 0
                fop.input.calculate_rate()
               
                circles.append(fop)
                probs = []
                sio.emit('restore', "r")


        elif event.type == pygame.MOUSEBUTTONUP:
           
            Mouse_x, Mouse_y = pygame.mouse.get_pos()
            sav = Person(CURRENT_PERSON)
            if event.button == 3:
                sav.hasCovid = 1
            else:
                sav.hasCovid = 0
            sav.x = Mouse_x
            sav.y = Mouse_y
            sav.input.history_graph = random.randint(1,10) #algorithm
            sav.input.time_last_g = random.randint(0,10) #algorithm
            sav.input.visit_danger_zone = random.randint(0,1) #algorithm
            sav.input.cross_covid = random.randint(0,5) #algorithm

            sav.input.home_danger_zone = random.randint(0,1) #input
            sav.input.work_public_area_medicine = random.randint(0,1) #algorithm
            sav.input.search_synt = random.randint(0,1) #algorithm

            probs.append(sav)
            circles.append(sav)
            CURRENT_PERSON+=1
            sio.emit('message', {'hasCovid':sav.hasCovid,'response': CURRENT_PERSON, "x":sav.x, "y":sav.y})


    if PASS_DAYS%380==0:
        fop.input.visit_danger_zone = 0
        if fop.input.cross_covid > 0:
            fop.input.cross_covid -= 1
        if fop.input.history_graph > 1:
            fop.input.history_graph -= 1
    win.fill((0,3,35))
    it_fps = int(fpsClock.get_fps())
    for item in probs:
        probSav = font2.render("PROB:" +str(round(item.input.calculate_rate(),2)), True, pygame.Color('white'))
        win.blit(probSav, (item.x, item.y))
    if PASS_DAYS%60==0:
        CURRENT_DAYS +=1
    fps = font2.render("FPS:" +str(it_fps), True, pygame.Color('white'))
    win.blit(fps, (20, 20))
    fps = font2.render("History:" +str(fop.input.history_graph), True, pygame.Color('white'))
    win.blit(fps, (20, 40))

        
    listSegments = []
    for x in range(SEGMENTS[0]):
        for y in range(SEGMENTS[1]):
            w = canvasWidth/SEGMENTS[0]
            h = canvasHeight/SEGMENTS[1]
            s = Segment()
            s.x = w * x
            s.y = h * y
            s.width= w
            s.height= h
            rect = pygame.Rect(s.x, s.y, s.width, s.height)
            listSegments.append(s)
            pygame.gfxdraw.rectangle(win, rect, (100,0,100))
            



    fps = font.render("DAYS: "+str(CURRENT_DAYS), True, pygame.Color('white'))
    win.blit(fps, (50, 600))
    update()
    redrawGameWindow()
    fpsClock.tick(FPS)
    PASS_DAYS+=1
    

sio.disconnect()
pygame.quit()