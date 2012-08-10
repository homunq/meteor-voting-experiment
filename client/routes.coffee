class MyRouter extends ReactiveRouter
  routes:
    '': 'new_election'
    'election/:eid': 'election'
    
  new_election: ->
    console.log 'newww'
    console.log Backbone.history.getFragment()
    login_then ->
      Meteor.call 'new_election', ->
        console.log 'qwpr' + JSON.stringify Meteor.user()
    #@navigate 'election/new',
    #  trigger: true

  election: (eid) ->
    login_then ->
      Meteor.call 'join_election', eid, ->
        console.log 'asdt' + JSON.stringify Meteor.user()
        @goto 'election'

@myrouter = new MyRouter()

Meteor.startup ->
  Backbone.history.start
     pushState: true
  Meteor.autosubscribe ->
    eid = Meteor.user()?.eid
    if eid
      myrouter.navigate 'election/' + eid,
        trigger: false
      Meteor.subscribe 'election',
        eid: eid
