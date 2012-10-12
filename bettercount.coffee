
        
if Meteor.is_client
  console.log "client"
 
if (Handlebars?) 
  Handlebars.registerHelper "eid", ->
    Meteor.user()?.eid
    
  Handlebars.registerHelper "election", ->
    Session.get 'election'
    
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
    
  Handlebars.registerHelper 'method', ->
    e = Session.get 'election'
    e?.method
    
  Handlebars.registerHelper 'meth_subtemplate', (sub) ->
    e = Session.get 'election'
    new Handlebars.SafeString Template["#{ e?.method }_#{ sub }"]()
    
  Handlebars.registerHelper 'dmeth_subtemplate', (sub) ->
    e = Session.get 'election'
    new Handlebars.SafeString '#{ e?.method }_#{ sub }' + ': ' + Template["#{ e?.method }_#{ sub }"]()
    
  Handlebars.registerHelper 'scenario', ->
    e = Session.get 'election'
    e.scenario
    
  Handlebars.registerHelper 'stage', ->
    console.log 'stage'
    e = Session.get 'election'
    if e?.round?
      steps = Meteor.user().steps
      if steps?.length >= e.round
        return steps[e.round]
    "init"
  
   
if Meteor.is_server
  Meteor.startup ->


# code to run on server at startup
