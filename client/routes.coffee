class @MyRouter extends ReactiveRouter
  routes:
    '': 'watchElection'
    'election/:eid': 'inElection'
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

  inElection: (eid) =>
    console.log "route: election"
    login_then =>
      console.log "route: election; logged in"
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
    Meteor.logout()

global = @

global.Router = new MyRouter()

Meteor.startup ->
  console.log 'startup router'
  Backbone.history.start
     pushState: true
  Meteor.autosubscribe ->
    eid = Meteor.user()?.eid
    if eid
      console.log "routing to election"
      Router.navigate 'election/' + eid,
        trigger: true #some redundancy here but no big problem
      Meteor.subscribe 'election',
        eid: eid