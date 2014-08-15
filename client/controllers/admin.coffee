

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
      if voter.nVoted
        if voter.manuallySet
          q=4
            #debug "#"
        else
          
          debug "echo \"#next voter", voter.stickyWorkerId, voter.paymentDue, voter.nSteps, voter.nVoted, '"'
          
          
          if voter.stickyAssignmentId
            debug "WTFWTF?????"
          voter.stickyAssignmentId = voter.assignmentId #TEMP - DELETE
          
          
          
          prefix = (if voter.stickyAssignmentId is "ASSIGNMENT_ID_NOT_AVAILABLE" then "#" else "")
          #if prefix isnt "#" #and voter.manuallySet and not voter.old
          if true or voter.paymentDue > 0
            debug("./grantBonus.sh -assignment", voter.stickyAssignmentId, 
              "-amount", "0.01" #accounting.formatMoney(voter.paymentDue/100,""), 
              "-workerid", voter.stickyWorkerId,
              '-reason "Good work."'
            )
            debug "#./assignQualification.sh -qualtypeid 3HRCVKUHL3W1J5HR0CWK9CR3A6GRTG -workerid", voter.stickyWorkerId
            #debug "#"
          #debug prefix, "./approveWork.sh -force -assignment", voter.stickyAssignmentId
          #debug "#"
      
    #debug "paymentList", voters
    voters
        
  Handlebars.registerHelper 'questions', ->
    SURVEY = new SurveyResponse
    questions = ({name:Object.keys(question)[0]} for question in SURVEY.questions)
    debug "questions helper"#, questions
    questions
    
  Handlebars.registerHelper 'answerers', ->
    SURVEY = new SurveyResponse
    debug "answerers helper"
    query = Session.get 'QUERY'
    responses = SurveyResponses.find query,
      sort:
        election:1
    responses = responses.fetch()
    theElections = _.uniq((response.election for response in responses),yes)
    outcomes = Outcomes.find
      election:
        $in: theElections
    global.outcomeDict = {}
    for outcome in outcomes.fetch()
      outcomeDict[outcome.election + outcome.stage] = outcome
    for response in responses
      #debug "response", response
      response.answerList = for question in SURVEY.questions
        response[Object.keys(question)[0]]
      responder = Meteor.users.findOne
        _id: response.voter
      outcome1 = outcomeDict[response.election + "1"]
      response.faction = responder?.faction
      response.method = outcome1?.method
      response.scenario = outcome1?.scenario
      response.payoffs = for i in [1..3]
        Scenarios[response.scenario]?.payoffs[outcomeDict[response.election + i].winner]?[response.faction]
    responses
      
      
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
    global.theElections = _.uniq((vote.election for vote in votes),yes)
    outcomes = Outcomes.find
      election:
        $in: theElections
    global.outcomeDict = {}
    for outcome in outcomes.fetch()
      outcomeDict[outcome.election + outcome.stage] = outcome
    for vote in votes
      scen = Scenarios[vote.scenario]
      meth = Methods[vote.method]
      vote.support = []
      for i in [0...scen.numCands()]
        vote.support[scen.candForFaction(i,vote.faction)] = meth.normSupportFor(i, vote.vote)
      vote.thisWinner = outcomeDict[vote.election + vote.stage]?.winner
      vote.thisPayoff = scen.payoffs[vote.thisWinner]?[vote.faction]
      vote.prevPayoff = scen.payoffs[vote.prevWinner]?[vote.faction]
      vote.thisTies = outcomeDict[vote.election + vote.stage]?.ties
      vote.prevTies = outcomeDict[vote.election + (vote.stage - 1)]?.ties
    votes
      
      
