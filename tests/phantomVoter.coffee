hasNext = ->
  
llog = (thread, args...) ->
  console.log ("    " for i in [0...thread]).join(""), args...
  
uniqueId = (length=8) ->
  id = ""
  id += Math.random().toString(36).substr(2) while id.length < length
  id.substr 0, length
  

links = []

#url = "http://bettercount.rs.af.cm//?asdt"
urlStem = "http://127.0.0.1:3000/new?workerId="
result = [0...2]
casperFactory = no
for x in result
  total = 1
  llog x, "hi"
  newCasperFactory = require('casper')
  if casperFactory and (newCasperFactory is casperFactory)
    llog x, "fuck", casperFactory, newCasperFactory
  casperFactory = newCasperFactory
  casper = casperFactory.create()
  require.uncache()
  do (x, casper) ->
    result[x] = 
      times: []
      election: no
      error: no
    url = urlStem + uniqueId() + "&slogNum=" + x
    casper.start url, ->
      # search for 'casperjs' from google form
      #@click "#nextStep"
      llog x, "hmmm..."
      result[x].times[0] = (new Date()).getTime()
      llog x, "logout", @evaluate ->
        newUser()
      @open url
      
    
    casper.waitForSelector "#nextStep", (->
      result[x].times[1] = (new Date()).getTime()
      llog x, "result"
      llog x, "hi"
      llog x, result[x].times
      llog x, "I've waited for "+ (result[x].times[1] - result[x].times[0]) + "   " + total
      total += 1
      @waitForSelector "#nextStep", (->
          llog x, "Got #nextStep twice, clicking"
          try
            @click "#nextStep"
            llog x, "clicked"
          catch e
            llog x, "QQQQQQQQQ", e
            llog x, @getHTML "body"
            llog x, @exists "#nextStep"
        ), (->
          llog x, "too slow dude"
          llog x, @getHTML "body"
          llog x, @exists "#nextStep"
        ), 30000
      yes
    ), -> 
      result[x].error = yes
      llog x, "timed out suckah" + x + " after " + (new Date().getTime() - result[x].times[0])
      llog x, @getHTML "body"
      llog x, @exists "#nextStep"
    , 60000
    casper.then ->
      llog x, "then"
      
    printIt = yes
    do (printIt) ->
      casper.waitFor (-> #step 3
        results = @evaluate ->
          [Session.get("step"), ELECTION]
        llog x, "step,election=", results
        [step, election] = results
        #llog x, "election"          
        if step isnt undefined
          if printIt
            for key, val of (election or {})
              llog x, key, val
            llog x, "THE step", step
            printIt = no
        else
          llog x, "no", step, election
        result[x]?.election = election
        return step == 2
      ), (->
        result[x].times[2] = (new Date()).getTime()
        llog x, "2. I've waited for "+ (result[x].times[2] - result[x].times[1]) + "   " + total
        @waitForSelector "#nextStep", (->
          llog x, "Got #nextStep twice, clicking"
          try
            @click "#nextStep"
            llog x, "clicked"
          catch e
            llog x, "QQQQQQQQQ", e
            llog x, @getHTML "body"
            llog x, @exists "#nextStep"
        ), (->
          llog x, "too slow dude"
        ), 30000
      ), ->
        result[x].error = yes
        llog x, "timed out suckah2" + x + " after " + (new Date().getTime() - result[x].times[0])
      , 60000
      
    casper.waitFor -> #step 4, practice
        step = @evaluate ->
          Session.get("step")
        return step == 3
      , ->
        result[x].times[3] = (new Date()).getTime()
        llog x, "3. I've waited for "+ (result[x].times[3] - result[x].times[2]) + "   " + total
        @waitForSelector "#nextStep", (->
          llog x, "Got #nextStep twice, clicking"
          try
            @click "#nextStep"
            llog x, "clicked"
          catch e
            llog x, "QQQQQQQQQ", e
            llog x, @getHTML "body"
            llog x, @exists "#nextStep"
        ), (->
          llog x, "too slow dude"
        ), 30000
      , ->
        result[x].error = yes
        llog x, "timed out suckah2" + x + " after " + (new Date().getTime() - result[x].times[0])
      , 60000
      
    casper.run ->
      # display results
      llog x, "method counts: ", _.countBy result, (aResult) ->
        aResult.election.method 
      llog x, "done!!!!", x, results
      