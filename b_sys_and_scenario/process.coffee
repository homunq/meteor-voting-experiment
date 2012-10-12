nobind = (f) ->
  f.nobind = true
  f
  
class Step
  constructor: (@name, @num, options) ->
    _.extend @, options
    
class Process
  constructor: (@name, steps...) ->
    @steps = []
    @firstInStages = []
    priorStage = 0
    for step in steps
      for name, options of step
        @steps.push new Step(name, @steps.length, options)
        if options.stage > priorStage
          @firstInStages[options.stage] = @steps.length
        priorStage = options.stage
        
  
  step: (num) ->
    @steps[num]

PROCESS = new Process "Base",
  countdown:
    suggestedMins: 0
    maxMins: 60
    stage: 0
    longName: "Countdown and outline"
    blurb: "See an outline of the experiment, and wait for the countdown to end and the experiment to begin."
, 
  consent:
    suggestedMins: 0
    maxMins: 0
    stage: 0
    prereqForNextStage: true
    longName: "Consent form"
    blurb: "Understand your rights and consent to the experiment."
, 
  scenario:
    suggestedMins: 2
    maxMins: 3
    stage: 0
    longName: "Scenario (Candidates, voters, and payouts)"
    blurb: "Understand how much you and other voters will earn depending on which of the virtual candidates wins."
, 
  system:
    suggestedMins: 2
    maxMins: 3
    stage: 0
    longName: "System (ballots and counting)"
    blurb: "Understand the voting system which will be used: how to fill out your ballot, and how ballots will be counted to find a winner."
, 
  practice:
    suggestedMins: 1
    maxMins: 4
    stage: 1
    prereqForNextStage: true
    longName: "Practice voting"
    blurb: "Vote once for practice (no payout)."
, 
  results:
    suggestedMins: 1
    maxMins: 2
    stage: 2
    longName: "Practice results"
    blurb: "See results of the practice election: the winner and how much you would have been paid."
, 
  voting:
    suggestedMins: 0.5
    maxMins: 2
    stage: 2
    prereqForNextStage: true
    longName: "Voting round 1"
    blurb: "Vote. You will be paid based on results."
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
, 
  payouts:
    suggestedMins: 0.5
    maxMins: 1
    stage: 4
    prereq: -1 #a full set of voters must be through the step 1 earlier before anyone starts this step
    longName: "Payout round 2"
    blurb: "See results of the round 2 election: the winner and how much you will be paid. (Payments will arrive within 1 day)"
, 
  survey:
    suggestedMins: 2
    maxMins: 10
    stage: 4
    prereqForNextStage: true
    longName: "Survey"
    blurb: "5-6 simple questions each about:<ul><li>you (gender, country, etc)</li><li>the voting system you used (on a 1-7 scale)</li><li>your general comments about the experiment</li></ul>"

    
if (Handlebars?) 
  Handlebars.registerHelper "steps", ->
    steps = []  
    for step, stepNum in PROCESS.steps
      steps.push  Template.oneStep
        stepNum: stepNum + 1
        stepName: step.name.charAt(0).toUpperCase() + step.name.slice(1)
        thisStep: stepNum == 3
    new Handlebars.SafeString steps.join ""
    
    
  Handlebars.registerHelper 'stepName', ->
    console.log 'stepName'
    s = Meteor.user?.step
    if s
      PROCESS.steps[s].name
    "init"
    
StepRecords = new Meteor.Collection 'stepRecords', null

class StepRecord extends StamperInstance
  
  collection: StepRecords
  
  constructor: (props) ->
    props ?=
      voter = 
      election = Session.get('election')._id
    super props
    
  @fields
    created: ->
      now = new Date
      now.getTime()
    data: {}
    voter: ->
      Meteor.user()._id
    step: ->
      Meteor.user().step
    election: ->
      Session.get('election')._id
    done: null #time
    
  @register
    finish: ->
      @userId().should.equal @voter
      if @canFinish()
        now = new Date
        @done = now.getTime()
        @save ->
        
          stepDoneBy = StepRecords.find(
                step: @step
                election: @election
                voter: @voter
              ).count()
              
          election.stepsDoneBy[@step] = stepDoneBy
          
          if PROCESS[@step].prereqForNextStage
            election.stage.should.equal PROCESS[@step].stage
            if (stepDoneBy >= election.scen().numVoters() or #full scenario
                  (election.stage > 0 and stepDoneBy >= election.voters.length)) #well at least everyone we have
              election.stage += 1
              
              if Meteor.is_server
                #move along everyone else who was waiting for that.
                stepToPromote = PROCESS.firstInStages[election.stage] - 1
                StepRecord.find(
                  election = @election
                  step = stepToPromote
                ).forEach (record) ->
                  if record.voter != @voter #that case is done below
                    Meteor.users.update
                      _id: record.voter
                    ,
                      $set:
                        step: stepToPromote + 1
                    ,
                      multi: false
         
          election.save()
            
          #move along if we can
          [thisStage, nextStage] = [PROCESS.steps[@step].stage, PROCESS.steps[@step + 1].stage]
          if election.stage >= nextStage
            Meteor.users.update
              _id: @voter
            ,
              $set:
                step: @step + 1
            ,
              multi: false
            
        
