

sT = (ms, fn) ->
  Meteor.setTimeout fn, ms


Meteor.startup ->
  Template.electionMaker.events
    'click #create': ->
      attrs = 
        scenario: $('#scenPicker option:selected').attr('value')
        method: $('#methPicker option:selected').attr('value')
        howManyMore: parseInt($('#howManyMore').val())
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
      MtUser.forElection eid, (error, result) ->
        Session.set "voters", result
      voters = []
    paymentList = Session.get "paymentList"
    nvoteList = Session.get "nvoteList"
    nvoteList ?= (["xx","yy"] for voter in voters)
    if paymentList is undefined
      paymentList = for voter, i in voters
        brainyVoter = new MtUser voter
        do (i) ->
          debug "brainyVoter", i
          brainyVoter.serverNumVoted (error, result) ->
            nvoteList[i] = result
            debug "brainyVoter replyN", i, error, result
            Session.set "nvoteList", nvoteList
            
          brainyVoter.serverCentsDue (error, result) ->
            debug "brainyVoter reply", i, error, result
            paymentList = (Session.get "paymentList") or ("xx" for voter in voters)
            paymentList[i] = result
            debug "brainyVoter reply", i, error, result, paymentList
            Session.set "paymentList", paymentList
    payments = for voter, i in voters
      _.extend voter,
        paymentDue: paymentList[i]
        nSteps: nvoteList[i][0]
        nVoted: nvoteList[i][1]
      sorryPaymentDue = voter.paymentDue + (if (parseInt(voter.nSteps) > 3) then 80 else 0)
      debug "#next voter", voter.paymentDue, voter.nSteps, voter.nVoted
      prefix = if voter.assignmentId is "ASSIGNMENT_ID_NOT_AVAILABLE" then "#" else ""
      debug prefix, "./approveWork.sh -assignment", voter.assignmentId
      if sorryPaymentDue > 0
        debug( prefix, "./grantBonus.sh -assignment", voter.assignmentId, 
            "-amount", accounting.formatMoney(sorryPaymentDue/100,""), 
            "-workerid", voter.stickyWorkerId,
            '-reason "Good work. We\'re adding $0.80 to the advertised payouts, because some workers\' delay meant that others were unable to vote in the second round."'
        )
      voter
             
        
    debug "paymentList", payments, paymentList
    payments
        
  Handlebars.registerHelper 'questions', ->
    SURVEY = new SurveyResponse
    questions = ({name:Object.keys(question)[0]} for question in SURVEY.questions)
    debug "questions", questions
    questions
    
  Handlebars.registerHelper 'answerers', ->
    SURVEY = new SurveyResponse
    debug "answerers helper"
    eid = Session.get 'adminEid'
    voters = Session.get "avoters"
    if voters is undefined
      MtUser.forElection eid, (error, result) ->
        Session.set "avoters", result
      voters = []
    if voters?.length
      answerersList = Session.get "answerersList"
      if answerersList is undefined
        answerersList = (("xxx" for question in SURVEY.questions) for voter in voters)
        
        for voter, i in voters
          brainyVoter = new MtUser voter
          do (i) ->
            brainyVoter.serverAnswers (error, result) ->
              answerersList[i] = result
              debug "brainyVoter replyN", i, error, result
              Session.set "answerersList", answerersList
              
               
          
      debug "answererslist", answerersList
      answerersList
