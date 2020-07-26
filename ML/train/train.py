import pandas as pd
import json

with open('data.json') as data_file:    
    js = json.load(data_file)
    df1 = pd.DataFrame(js)
    df1['orientation'] = 0; 

with open('topLeft.json') as data_file:    
    js = json.load(data_file)
    df2 = pd.DataFrame(js)
    df2['orientation'] = 1; 
df = pd.concat([df1,df2])
from sklearn.ensemble import RandomForestClassifier
clf = RandomForestClassifier(max_depth=20, random_state=0)
clf.fit(df.drop(['orientation'], axis=1), df['orientation'])


data_load=[-0.000335693359375, 7.62939453125, 0.0008087158203125, 0.50946044921875, \
           0.2362213134765625,9.800140380859375, -48,   0.09298295380957794, -59 ]
print(clf.predict_proba([data_load]))

import pickle

with open("model.pkl", 'wb') as file:
    pickle.dump(clf, file)