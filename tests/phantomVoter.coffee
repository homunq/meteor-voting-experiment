hasNext = ->
  

links = []
casperFactory = require('casper')

#url = "http://bettercount.rs.af.cm//?asdt"
url = "http://127.0.0.1:3000/?asdt"
result = [0..4]
for x in result
  total = 1
  console.log "hi"
  casper = casperFactory.create()
  do (x, casper) ->
    startTime = []
    casper.start url, ->
      # search for 'casperjs' from google form
      #@click "#nextStep"
      @echo "hmmm..."
      startTime[0] = new Date()
    
    casper.waitForSelector "#nextStep", ->
        result[x] = "Loaded"
        now = new Date()
        @echo "I've waited for "+ (now.getTime() - startTime[0].getTime()) + "   " + total
        total += 1
      , -> 
        @echo "timed out suckah" + x + " after " + (new Date().getTime() - startTime[0].getTime())
      , 60000
    #casper.then ->
    #  @click "#nextStep"
      
      
    casper.then ->
      @click "#nextStep"
      
    casper.then ->
      heads = @fetchText "h1"
      if heads.match /^You are in/
        result[x] = "in!"
      else
        result[x] = heads
      html = @evaluate ->
        html = $('html').clone()
        htmlString = html.html()
        return htmlString
      #@debugHTML()
      
    casper.run ->
      # display results
      @echo "done!!!!", x, results
      