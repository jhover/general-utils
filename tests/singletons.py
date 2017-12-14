#!/bin/env python

class OnlyOne(object):

    obj = None

    def __new__(cls, *args, **kwds):
        if OnlyOne.obj is not None:
            return OnlyOne.obj
        else:
            it = object.__new__(cls)
            it.init(*args, **kwds)
            return it      

    def __init__(self, val):
            self.val = val
    
    def __str__(self):
        s = "OnlyOne: val = %s" % self.val
        return s    
    
    
if __name__ == "__main__":
    print("Testing singleton creation.")
    oo = OnlyOne('one')
    oo2 = OnlyOne('two')
    print(oo)
    print(oo2)