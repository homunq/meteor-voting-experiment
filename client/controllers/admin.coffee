

sT = (ms, fn) ->
  Meteor.setTimeout fn, ms


Meteor.startup ->
  Handlebars.registerHelper 'elections', ->
    slog "reporting on electionsEOE"
    password = Session.get 'password'
    versionQuery =
      version: Session.get 'fromVersion'
    
    elections = Session.get 'elections'
    if not elections?
      Elections.adminSubscribe(password)
      sT 0, ->
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
      Voters.adminSubscribe(password)
      sT 0, ->
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
      StepRecords.adminSubscribe(password)
      sT 0, ->
        User.getAllFor query, password, 'StepRecords', (error, result) ->
          if result?
            Session.set 'stepRecords' + voter._id, result
    for stepRecord in (priorResult or [])
      stepRecord: stepRecord
      created: (new Date stepRecord.created).toLocaleTimeString()
  
  Handlebars.registerHelper 'payments', ->
    slog "payments helper"
    eid = Session.get 'adminEid'
    voters = Session.get "voters"
    if voters is undefined
      User.forElection eid, (error, result) ->
        Session.set "voters", result
      voters = []
    paymentList = Session.get "paymentList"
    if paymentList is undefined
      paymentList = for voter in voters
        brainyVoter = new MtUser voter
        do (i) ->
          slog "brainyVoter", i
          brainyVoter.serverCentsDue (error, result) ->
            slog "brainyVoter reply", i, error, result
            paymentList = (Session.get "paymentList") or ("xx" for voter in voters)
            paymentList[i] = result
            Session.set "paymentList", paymentList
    payments = for voter, i in voters
      _.extend voter,
        paymentDue: paymentList[i]
    slog "paymentList", payments, paymentList
    payments
        
