

sT = (ms, fn) ->
  Meteor.setTimeout fn, ms


Meteor.startup ->
  Template.electionMaker.events
    'click #create': ->
      attrs = 
        scenario: $('#scenPicker option:selected').attr('value')
        method: $('#methPicker option:selected').attr('value')
      Election.make attrs, true, 0, false, (result, error) =>
        Session.set "madeEid", result
        debug 'madeElection',  attrs#use that template
    
  Handlebars.registerHelper 'allMethods', ->
    return (name for name, meth of Methods)
    
  Handlebars.registerHelper 'allScenarios', ->
    return (name for name, scen of Scenarios)
    
  Handlebars.registerHelper 'elections', ->
    debug "reporting on electionsEOE"
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
    debug "payments helper"
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
          debug "brainyVoter", i
          brainyVoter.serverCentsDue (error, result) ->
            debug "brainyVoter reply", i, error, result
            paymentList = (Session.get "paymentList") or ("xx" for voter in voters)
            paymentList[i] = result
            Session.set "paymentList", paymentList
    payments = for voter, i in voters
      _.extend voter,
        paymentDue: paymentList[i]
    debug "paymentList", payments, paymentList
    payments
        
