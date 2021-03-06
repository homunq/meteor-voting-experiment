

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
      howManyMore = $('#howManyMore').val()
      if howManyMore.length
        howManyMore = parseInt howManyMore
      else
        howManyMore = undefined
      attrs = 
        scenario: $('#scenPicker option:selected').attr('value')
        method: method
        howManyMore: howManyMore
      Election.make attrs, true, 0, false, (result, error) =>
        Session.set "madeEid", result
        debug 'madeElection',  attrs#use that template
    
  Handlebars.registerHelper 'allMethods', ->
    return ['random'].concat(name for name, meth of Methods)
    
  Handlebars.registerHelper 'allScenarios', ->
    return (name for name, scen of Scenarios)
    
  Handlebars.registerHelper 'elections', ->
    debug "reporting on electionsEOE"
    query = Session.get 'QUERY'
    elections = Elections.find query
    elections = elections.fetch()
    for election in elections
      election.voteCounts = for s in [1..3]
        votes = Votes.find
          election: election._id
          stage: s
        votes.count()
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
        debug "echo \"#next voter", voter.stickyWorkerId, voter.paymentDue, voter.nSteps, voter.nVoted, '"'
        
        #if prefix isnt "#" #and voter.manuallySet and not voter.old
        if voter.paymentDue > 0
          debug("./grantBonus.sh -assignment", voter.stickyAssignmentId, 
            "-amount", accounting.formatMoney(voter.paymentDue/100,""), 
            "-workerid", voter.stickyWorkerId,
            '-reason "Good work."'
          )
          #debug "#./assignQualification.sh -qualtypeid 3HRCVKUHL3W1J5HR0CWK9CR3A6GRTG -workerid", voter.stickyWorkerId
          #debug "#"
        debug "./approveWork.sh -force -assignment", voter.stickyAssignmentId
        #debug "#"
      
    #debug "paymentList", voters
    voters
        
  Handlebars.registerHelper 'questions', ->
    SURVEY = new SurveyResponse
    questions = ({name:Object.keys(question)[0]} for question in SURVEY.questions \
            when not (question[Object.keys(question)[0]] instanceof Section) )
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
      voter = Meteor.users.findOne
        _id: response.voter
      outcome1 = outcomeDict[voter?.eid + "1"]
      votes = Votes.find
        voter: response.voter
        
      a=1  
        
        
      whenVoted = 0
      for vote in votes.fetch()
        whenVoted += 1 << (vote.stage - 1)
      _.extend response,
        whenVoted: whenVoted
        faction: voter.faction
        method: outcome1?.method
        scenario: outcome1?.scenario
        payoffs: for i in [1..3]
          Scenarios[outcome1?.scenario]?.payoffs[outcomeDict[voter?.eid + i].winner]?[voter?.faction]
        answerList: for question in SURVEY.questions when not (question[Object.keys(question)[0]] instanceof Section)
          response[Object.keys(question)[0]]
        showAveraged: voter.showAverageCondition
        blurbd: voter.blurbCondition
        subtotald: voter.subtotalCondition
          
          
          
          
          
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
    debug "outcomes"
    for outcome in outcomes.fetch()
      outcomeDict[outcome.election + outcome.stage] = outcome
    
    debug "outcomes done"  
    elections = Elections.find
      _id:
        $in: theElections
    electionsById = {}
    for election in elections.fetch()
      electionsById[election._id] = election
      
    debug "elections done"
    soFar = 0
    prevVoter = ""
    voterPtr = [{}]
    
    if votes.length > 0
      extraVoteAttrs(votes[0], electionsById, outcomeDict, voterPtr)
      console.log votes[0]
      attrNames = Object.keys votes[0]
      console.log attrNames.join "\t"
      for vote in votes
        extraVoteAttrs(vote, electionsById, outcomeDict, voterPtr)
        console.log (vote[attr] for attr in attrNames).join "\t"
    votes
      
      
@extraVoteAttrs = (vote, electionsById, outcomeDict, voterPtr) ->
  scen = Scenarios[vote.scenario]
  meth = Methods[vote.method]
  #vote.support = []
  #for i in [0...scen.numCands()]
  #  vote.support[scen.candForFaction(i,vote.faction)] = meth.normSupportFor(i, vote.vote)
  
  _.extend vote,
    stagey: vote.stage
    support: meth.orderBallot (meth.normBallot vote.vote, scen), scen, vote.faction
    rankedSupport: meth.orderBallot (meth.toQuasiRankedBallot(vote.vote, scen)), scen, vote.faction
    thisWinner: outcomeDict[vote.election + vote.stage]?.winner
    thisPayoff: scen.payoffs[vote.thisWinner]?[vote.faction]
    prevPayoff: scen.payoffs[vote.prevWinner]?[vote.faction]
    thisTies: outcomeDict[vote.election + vote.stage]?.ties
    prevTies: outcomeDict[vote.election + (vote.stage - 1)]?.ties
  
  if vote.voter is voterPtr[0]?.voter
    soFar += 1
  else
    soFar = 0
    voterPtr[0] = Meteor.users.findOne
      _id: vote.voter
      
  
    
  firstStep = StepRecords.findOne
    step: 1
    voter: vote.voter
  
  _.extend vote, electionsById[vote.election],
    voterCreated: firstStep?.created
      
    showAveraged: voterPtr[0]?.showAverageCondition
    blurbd: voterPtr[0]?.blurbCondition
    subtotald: voterPtr[0]?.subtotalCondition
    stagesSoFar: soFar
