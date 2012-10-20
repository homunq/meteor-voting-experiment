class @MyRouter extends ReactiveRouter
  routes:
    '': 'watchElection'
    'election/:eid': 'election'
    'elections/clear/all': 'clearAll'
    'elections/makeOne/:scenario/:method': 'makeElection'
    
  watchElection: ->
    console.log 'watch'
    console.log Backbone.history.getFragment()
    login_then ->
      Election.watchMain ->
        #console.log 'qwpr' + JSON.stringify Meteor.user()
    #@navigate 'election/new',
    #  trigger: true

  election: (eid) =>
    login_then =>
      Election.watch eid, =>
        #console.log 'asdt' + JSON.stringify Meteor.user()
        @goto 'loggedIn' #use that template
        
  clearAll: ->
    console.log "clear all"
    Election.clearAll()
    
  makeElection: (scenario, method) ->
    console.log "makeElection", scenario, method
    Election.make(
      scenario: scenario
      method: method
    , true)

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