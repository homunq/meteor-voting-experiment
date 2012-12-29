

Meteor.startup ->
  Handlebars.registerHelper 'elections', ->
    password = Session.get 'password'
    versionQuery =
      version: Session.get 'fromVersion'
    
    elections = Session.get 'elections'
    if not elections?
      Election.getAllFor versionQuery, password, 'Elections', (error, result) ->
        if result?
          Session.set 'elections', result
    elections
  Handlebars.registerHelper 'voters', (election) ->
    password = Session.get 'password'
    voters = Session.get 'voters' + election._id
    voterQuery = 
      eid: election._id
    if not voters?
      User.getAllFor voterQuery, password, 'USERS', (error, result) ->
        if result?
          Session.set 'voters' + election._id, result
    for voter in (voters or [])
      voter: voter
  Handlebars.registerHelper "ifDefined", (conditional, options) ->
    if conditional?
      options.fn this  
      
  Handlebars.registerHelper 'stepRecords', (voter) ->
    password = Session.get 'password'
    priorResult = Session.get 'stepRecords' + voter._id
    query = 
      voter: voter._id
    if not priorResult?
      User.getAllFor query, password, 'StepRecords', (error, result) ->
        if result?
          Session.set 'stepRecords' + voter._id, result
    for stepRecord in (priorResult or [])
      stepRecord: stepRecord
      created: (new Date stepRecord.created).toLocaleTimeString()
  