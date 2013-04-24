hasNext = ->
  

links = []
casperFactory = require('casper')

url = "http://bettercount.rs.af.cm//?asdt"
#url = "http://127.0.0.1:3000/?asdt"
for x in [1..25] 
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
        now = new Date()
        @echo "I've waited for "+ (now.getTime() - startTime[0].getTime()) + "   " + total
        total += 1
      , -> 
        @echo "timed out suckah" + x + " after " + (new Date().getTime() - startTime[0].getTime())
      , 60000
    #casper.then ->
    #  @click "#nextStep"
      
      
    casper.then ->
      html = @evaluate ->
        html = $('html').clone()
        htmlString = html.html()
        return htmlString
      #@debugHTML()
      
    casper.run ->
      # display results
      @echo "done!!!!"
      