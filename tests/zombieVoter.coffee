console.log "hw"

zombie = require "zombie"

browser = new zombie.Browser()

browser.setMaxListeners(0)

browser.
  visit("http://bettercount.meteor.com/?asdt"
  ).then(->
    console.log "loaded, waiting 5"
    browser.wait(5000)
  ).then(->
    console.log browser.html()
    browser.clickLink("#nextStep")
  ).then(->
    console.log browser.html
  ).fail( (err)->
    console.log "fail", err
    browser.windows.close()
  )
