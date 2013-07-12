from ghost import Ghost
import random

print "ok"

ghosts = [Ghost(wait_timeout=40) for a in range(3)]

for ghost in ghosts:
    ghost.open("http://127.0.0.1:3000/new?workerId="+str(random.randrange(9999)))

for i, ghost in enumerate(ghosts):
    print i
    ghost.wait_for_selector("#nextStep")
    print i
    ghost.click("#nextStep")
    print "clicked",i
    