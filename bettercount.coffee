
        
if Meteor.is_client
  console.log "client"
 
if (Handlebars?) 
  Handlebars.registerHelper "eid", ->
    Meteor.user()?.eid
    
  Handlebars.registerHelper "user", ->
    Meteor.user()?._id
    
  Handlebars.registerHelper 'rounder', ->
    e = Session.get 'election'
    if e?.round is 0
      return 'signup'
    else if e?.round > 0
      return 'election'
    'handshake'
    
  Handlebars.registerHelper 'round', ->
    e = Session.get 'election'
    e?.round
    
  Handlebars.registerHelper 'system', ->
    e = Session.get 'election'
    e?.system
    
    
  Handlebars.registerHelper 'scenario', ->
    e = Session.get 'election'
    e.scenario
    
  Handlebars.registerHelper 'step', ->
    e = Session.get 'election'
    if e?.round?
      steps = Meteor.user().steps
      if steps?.length >= e.round
        return steps[e.round]
    "init"
  
   
if Meteor.is_server
  Meteor.startup ->


# code to run on server at startup
