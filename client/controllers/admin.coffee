

Meteor.startup ->
  versionQuery =
    version: VERSION
  Handlebars.registerHelper 'elections', ->
    password = Session.get 'password'
    elections = Session.get 'elections'
    if not elections?
      Election.getAllFor versionQuery, password, 'Elections', (error, result) ->
        if result?
          Session.set 'elections', result
    elections
  Handlebars.registerHelper 'voters', (election) ->
    password = Session.get 'password'
    voters = Session.get 'voters' + election
    voterQuery = 
      eid: election._id
    if not voters?
      User.getAllFor voterQuery, password, 'USERS', (error, result) ->
        if result?
          Session.set 'voters' + election, result
    voters
    
  