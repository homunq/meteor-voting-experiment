class MyRouter extends ReactiveRouter
  routes:
    '': 'new_election'
    'election/:eid': 'election'
    
  new_election: ->
    console.log 'newww'
    console.log Backbone.history.getFragment()
    login_then ->
      Election.make ->
        #console.log 'qwpr' + JSON.stringify Meteor.user()
    #@navigate 'election/new',
    #  trigger: true

  election: (eid) =>
    login_then =>
      Election.join eid, =>
        #console.log 'asdt' + JSON.stringify Meteor.user()
        @goto 'loggedIn'

@Router = new MyRouter()

Meteor.startup ->
  Backbone.history.start
     pushState: true
  Meteor.autosubscribe ->
    eid = Meteor.user()?.eid
    if eid
      Router.navigate 'election/' + eid,
        trigger: false
      Meteor.subscribe 'election',
        eid: eid
        
if (Handlebars) 
  Handlebars.registerHelper 'rounder', ->
    e = Session.get 'election'
    if e?.round is 0
      return 'signup'
    else if e?.round > 0
      return 'election'
    'handshake'
  Handlebars.registerHelper 'round', ->
    e = Session.get 'election'
    e.round
    
    
  Handlebars.registerHelper 'system', ->
    e = Session.get 'election'
    e.system
    
    
  Handlebars.registerHelper 'scenario', ->
    e = Session.get 'election'
    e.scenario
    
  Handlebars.registerHelper 'step', ->
    Meteor.user().step ? "init"
  