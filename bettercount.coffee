if Meteor.is_client
  Template.hello.greeting = ->
    "Welcome to bettercount."
    
  Template.hello.round_is = (round) ->
    console.log round, (Session.get "round"), round == Session.get "round"
    round == Session.get "round"

  Template.hello.events = "click input": ->
    
    # template data, if any, is available in 'this'
    console.log "You pressed the button"  if typeof console isnt "undefined"
if Meteor.is_server
  Meteor.startup ->


# code to run on server at startup
