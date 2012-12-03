nobind = (f) ->
  f.nobind = true
  f
  
chai.should()

class Step
  constructor: (@name, @num, options) ->
    _.extend @, options
    
  canFinish: (stepRecord) -> #can be overloaded at instance level in options+
    true 
    
class Process
  constructor: (@name, steps...) ->
    @steps = []
    @firstInStages = []
    priorStage = 0
    @suggestedMins = @maxMins = 0
    for step in steps
      for name, options of step
        if (Handlebars?)
          options.blurb = new Handlebars.SafeString options.blurb
          
        @steps.push new Step(name, @steps.length, options)
        
        if options.stage > priorStage
          @firstInStages[options.stage] = @steps.length - 1
        priorStage = options.stage
        
        @suggestedMins += options.suggestedMins
        @maxMins += options.maxMins
  
  step: (num) ->
    @steps[num]

PROCESS = new Process "Base",
  consent:
    suggestedMins: 0
    maxMins: 60
    stage: 0
    longName: "Outline, countdown, and consent"
    blurb: "See an outline of the experiment, and wait for the countdown to end and the experiment to begin."
    prereqForNextStage: true
    beforeFinish: (cb) ->
      election = Session.get 'election'
      election.addVoterAndSave Meteor.user()._id, cb
, 
  scenario:
    suggestedMins: 2 
    maxMins: 3
    stage: 0
    longName: "Scenario (Candidates, voters, and payouts)"
    blurb: "Understand how much you and other voters will earn depending on which of the virtual candidates wins."
    popover: true
, 
  method:
    suggestedMins: 2
    maxMins: 3
    stage: 0
    longName: "Election method (ballots and counting)"
    blurb: "Understand the voting system which will be used: how to fill out your ballot, and how ballots will be counted to find a winner."
, 
  practice:
    suggestedMins: 1
    maxMins: 4
    stage: 1
    prereqForNextStage: true
    longName: "Practice voting (round 0)"
    blurb: "Vote once for practice (no payout)."
    beforeFinish: (cb) ->
      election = Session.get 'election'
      election.addVote VOTE.raw(), cb
, 
  results:
    suggestedMins: 1
    maxMins: 2
    stage: 2
    longName: "Practice results (round 0)"
    blurb: "See results of the practice election: the winner and how much you would have been paid."
, 
  voting:
    suggestedMins: 0.5
    maxMins: 2
    stage: 2
    prereqForNextStage: true
    longName: "Voting round 1"
    blurb: "Vote. You will be paid based on results."
    beforeFinish: (cb) ->
      election = Session.get 'election'
      election.addVote VOTE.raw(), cb
, 
  payouts:
    suggestedMins: 1
    maxMins: 2
    stage: 3
    longName: "Payout round 1"
    blurb: "See results of the round 1 election: the winner and how much you will be paid. (Payments will arrive within 1 day)"
, 
  voting:
    suggestedMins: 0.5
    maxMins: 2
    stage: 3
    prereqForNextStage: true
    longName: "Voting round 2"
    blurb: "Vote. You will be paid again based on results."
    beforeFinish: (cb) ->
      election = Session.get 'election'
      election.addVote VOTE.raw(), cb
, 
  payouts:
    suggestedMins: 1
    maxMins: 2
    stage: 4
    prereq: -1 #a full set of voters must be through the step 1 earlier before anyone starts this step
    longName: "Payout round 2"
    blurb: "See results of the round 2 election: the winner and how much you will be paid. (Payments will arrive within 1 day)"
, 
  survey:
    suggestedMins: 2
    maxMins: 7
    stage: 4
    prereqForNextStage: false
    longName: "Survey"
    blurb: "4-5 simple questions each about:<ul><li>you (gender, country, etc)</li><li>the voting system you used (on a 0-7 scale)</li><li>your general comments about the experiment</li></ul>"
    beforeFinish: (cb) ->
      sendSurvey cb
, 
  debrief:
    suggestedMins: 1
    maxMins: 3
    stage: 4
    prereqForNextStage: true
    longName: "Debrief"
    blurb: "Thanks for participating, and a simple explanation of what we hope to learn from this study. Submit job and receive base pay."

    
    
StepRecords = new Meteor.Collection 'stepRecords', null

if Meteor.is_server
  Meteor.publish 'stepRecords', (uid) ->
    StepRecords.find
      user: uid
  StepRecords.allow
    insert: ->
      true
else  
  Meteor.autosubscribe ->
    user = Meteor.user()
    if user?
      Meteor.subscribe 'stepRecords', user._id

class StepRecord extends StamperInstance
  
  collection: StepRecords
  
  constructor: (props) ->
    if Meteor.user? and not props?
      u = Meteor.user()
      props =
        voter: u?._id
        step: u?.step
        election: u?.eid
    super props
    
  @fields
    created: ->
      now = new Date
      now.getTime()
    data: {}
    voter: null
    step: null
    election: null
    done: null #time
    
  @register
    finished: ->
      #console.log "save StepRecord 1"
      stepDoneBy = StepRecords.find(
            step: @step
            election: @election
          ).count()
          
      
      if Meteor.is_client and OPTIMIZE? #faster but harder to debug
        election = Session.get "election"
      else
        election = new Election Elections.findOne
          _id: @election
      #console.log "save StepRecord 2", @, election, PROCESS.step(@step)#, _(@).pairs()
      election.stepsDoneBy[@step] = stepDoneBy
      
      if PROCESS.step(@step).prereqForNextStage
        #console.log "save StepRecord 3"
        election.stage.should.equal PROCESS.step(@step).stage
        if (stepDoneBy >= election.scen().numVoters() or #full scenario
              (election.stage > 0 and stepDoneBy >= election.voters.length)) #well at least everyone we have
          
          #console.log "save StepRecord 4"
          election.stage += 1
          
          #if Meteor.is_server
          #  #move along everyone else who was waiting for that.
          #  stepToPromote = PROCESS.firstInStages[election.stage] - 1
          #  #console.log "save StepRecord 4.5", @election, stepToPromote, StepRecords.find({election: @election}).fetch()
          #  StepRecords.find(
          #    election: @election
          #    step: stepToPromote
          #  ).forEach (record) ->
          #    
          #    #console.log "save StepRecord 5"
          #    if record.voter != @voter #that case is done below
          #      Meteor.users.update
          #        _id: record.voter
          #      ,
          #        $set:
          #          step: stepToPromote + 1
          #      ,
          #        multi: false
     
      #console.log "save StepRecord 6", election
      election.save() 
        
      #move along if we can
      [thisStage, nextStage] = [PROCESS.step(@step).stage, PROCESS.step(@step + 1).stage]
      if election.stage >= nextStage
        
        #console.log "save StepRecord 7"
        @moveOn()
          
      else
        Session.set "stepWaitingForStage", nextStage
          
    moveOn: ->
      #console.log "moving on to step ",@step + 1
      Meteor.users.update
        _id: @voter
      ,
        $set:
          step: @step + 1
      ,
        multi: false
              
              
  finish: ->
    if @canFinish()
      now = new Date
      @done = now.getTime()
      @save =>
        #console.log "finished:", @
        @finished()
        @after()
    else #can't finish
      #console.log "can't finish stepRecord!"
  
  after: ->
    if PROCESS.step(@step).after?
      PROCESS.step(@step).after()
          
  canFinish: ->
    PROCESS.step(@step).canFinish @
            
@stepRecord = undefined
  
#

Meteor.startup ->
  ##console.log _.keys Meteor
  if Meteor.is_client
    Meteor.autosubscribe ->
      step = Session.get "step"
      if step? and step != stepRecord?.step
        #console.log "New step"
        window.stepRecord = new StepRecord()

    Meteor.autosubscribe ->
      stepWaitingForStage = Session.get "stepWaitingForStage"
      if stepWaitingForStage
        stage = Session.get "stage"
        if stage is stepWaitingForStage
          Session.set "stepWaitingForStage", no
          stepRecord.moveOn()
          
NextStep = ->
  beforeFinish = PROCESS.step(stepRecord.step).beforeFinish
  #console.log "beforeFinish", beforeFinish
  if beforeFinish
    beforeFinish (error, result) ->
      #console.log "beforeFinish done", error, result
      if !error
        #console.log "NextStep"
        stepRecord.finish()
      else
        #console.log error
        Session.set "error", error.reason
  else
    #console.log "NextStep direct"
    stepRecord.finish()
