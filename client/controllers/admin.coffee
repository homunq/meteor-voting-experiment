

sT = (ms, fn) ->
  Meteor.setTimeout fn, ms

global = @
@EQUERY = undefined 

Meteor.startup ->
  Template.electionMaker.events
    'click #create': ->
      method = $('#methPicker option:selected').attr('value')
      if method is 'random'
        method = _.sample METHOD_WHEEL
      attrs = 
        scenario: $('#scenPicker option:selected').attr('value')
        method: method
        howManyMore: parseInt($('#howManyMore').val())
      Election.make attrs, true, 0, false, (result, error) =>
        Session.set "madeEid", result
        debug 'madeElection',  attrs#use that template
    
  Handlebars.registerHelper 'allMethods', ->
    return ['random'].concat(name for name, meth of Methods)
    
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
    query = Session.get 'QUERY'
    voters = Meteor.users.find query, 
      sort:
        eid:1
        faction:1
    voters = for voter in voters.fetch()
      new MtUser voter
    
      
    for voter in voters
      [voter.nSteps, voter.nVoted] = (voter.numVoted() or [0,0])
      voter.paymentDue = voter.centsDue()
      if voter.nSteps
        #debug "#next voter", voter.paymentDue, voter.nSteps, voter.nVoted
        prefix = (if voter.assignmentId is "ASSIGNMENT_ID_NOT_AVAILABLE" then "#" else "")
        if prefix is "#" and voter.manuallySet and not voter.old
          if voter.paymentDue > 0
            debug("./grantBonus.sh -assignment", voter.stickyAssignmentId, 
              "-amount", accounting.formatMoney(voter.paymentDue/100,""), 
              "-workerid", voter.stickyWorkerId,
              '-reason "Good work."'
            )
            #debug "#"
          #debug prefix, "./approveWork.sh -force -assignment", voter.assignmentId
          #debug "#"
      
    #debug "paymentList", voters
    voters
        
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
      
      
  Handlebars.registerHelper 'adminVoters', ->
    debug "adminVoters helper"
    equery = Session.get 'QUERY'
    electionSet = Elections.find equery
    electionSet = electionSet.fetch()
    voters = []
    for election in electionSet
      debug "election", election._id
      eVotes = Votes.find
        election: election._id
        yes and 
          sort:
            faction:1
            voter:1
            stage:1
      lastVoter = {}
      for vote in eVotes.fetch()
        if vote.voter isnt lastVoter.voter
          if lastVoter.voter
            voters.push lastVoter
          lastVoter = vote
        lastVoter["v#{vote.stage}"] = vote
      voters.push lastVoter
    voters
      
    
  Handlebars.registerHelper 'adminVotes', ->
    debug "adminVoters helper"
    query = Session.get 'QUERY'
    voteSet = Votes.find query,
      sort:
        election:1
        faction:1
        voter:1
        stage:1
    votes = voteSet.fetch()
    elections = _.uniq([vote.election for vote in votes],yes)
    outcomes = Outcomes.find
      election:
        $in: elections
    outcomeDict = {}
    for outcome in outcomes.fetch()
      outcomeDict[outcome.election + outcome.stage] = outcome
    for vote in votes
      scen = Scenarios[vote.scenario]
      meth = Methods[vote.method]
      vote.support = []
      for i in [0...scen.numCands()]
        vote.support[scen.candForFaction(i,vote.faction)] = meth.normalize(vote.vote[i], scen.numCands)
      vote.thisWinner = outcomeDict[vote.election + vote.stage].winner
      vote.thisPayoff = scen.payoffs[vote.thisWinner]?[vote.faction]
      vote.prevPayoff = scen.payoffs[vote.prevWinner]?[vote.faction]
      vote.thisTies = outcomeDict[vote.election + vote.stage]?.ties
      vote.prevTies = outcomeDict[vote.election + (vote.stage - 1)]?.ties
    votes
      
      
