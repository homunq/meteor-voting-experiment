class @MyRouter extends ReactiveRouter
  routes:
    '': 'newElection'
    'election/:eid': 'election'
    'elections/clear/all': 'clearAll'
    
  newElection: ->
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
        
  clearAll: ->
    console.log "clear all"
    Election.clearAll()

global = @

global.Router = new MyRouter()

Meteor.startup ->
  console.log 'startup router'
  Backbone.history.start
     pushState: true
  Meteor.autosubscribe ->
    eid = Meteor.user()?.eid
    if eid
      Router.navigate 'election/' + eid,
        trigger: false
      Meteor.subscribe 'election',
        eid: eid