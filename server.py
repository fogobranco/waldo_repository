import eventlet
import socketio
from sklearn.ensemble import RandomForestClassifier
import pickle 


sio = socketio.Server()
app = socketio.WSGIApp(sio, static_files={
})

@sio.event
def connect(sid, environ):
    print('connect ', sid)

@sio.event
def restore(sid, data):
    sio.emit('restore', data, broadcast=True, include_self=False)

@sio.event
def message(sid, data):
    sio.emit('message', data, broadcast=True, include_self=False)

arr = []
@sio.event
def plain(sid, data):
    
    with open('ML/train/model.pkl', 'rb') as pickle_file:
        model = pickle.load(pickle_file)
        response = (model.predict_proba([list(data.values())]))

    sio.emit('calculate', {"calculate":203, "predict":[response[0][0], response[0][1]]})

@sio.event
def calculate(sid, data):
    sio.emit('calculate', data, broadcast=True, include_self=False)


@sio.event
def disconnect(sid):
    print('disconnect ', sid)

if __name__ == '__main__':
    eventlet.wsgi.server(eventlet.listen(('0.0.0.0', 8765)), app)