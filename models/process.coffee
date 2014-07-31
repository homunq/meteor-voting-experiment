###
This is the structure that controls the sequence of steps in the experiment. However, the early and last stages happen
in interaction with the AMT interface, so here is an explanation of what the user should see and do through the process

Step -1: On MT, user sees hit summary
  click on hit to see detail
0: static URL with "overview"
  click on "next"
1: switch URL; consent form
  click "next"
1.99: "now take the HIT"
  take HIT
2: scenario
  "next"
3-10: etc
  "submit"
999: "Thanks"

so, only 2-10 should have workerId in url. If you take the HIT prematurely, you should get told to give it back, and 
there MAY be another chance on another identical HIT. If you are on step 2-9 without a HIT, you should be told to take it.

In all cases, reloading should get you the same step of the same experiment.



###


Snobind = (f) ->
  f.nobind = true
  f
  
chai.should()

class @Step
  constructor: (@name, @num, options) ->
    _.extend @, options
    if @payout? and Meteor.isClient
      @payout = new Handlebars.SafeString @payout()
    
  canFinish: (stepRecord) -> #can be overloaded at instance level in options+
    true 
    
class @Process
  constructor: (@name, steps...) ->
    @steps = []
    @firstForStages = [1]
    priorStage = steps[0].stage
    @suggestedMins = @maxMins = 0
    for step in steps
      for name, options of step
        if (Handlebars?.SafeString?)
          options.blurb = new Handlebars.SafeString options.blurb
          
        @steps.push new Step(name, @steps.length, options)
        
        if options.prereqForNextStage
          @firstForStages[options.stage + 1] = @steps.length #@steps.length is the number of the NEXT step
        priorStage = options.stage
        
        if not options.hide
          @suggestedMins += options.suggestedMins
          @maxMins += options.maxMins
          
  step: (num) ->
    @steps[num]
    
  minsForStage: (stage) ->
    #debug "minsForStage", stage
    if stage >= @firstForStages.length - 2
      return -1
    mins = 0
    stepToTime = @firstForStages[stage]
    while @steps[stepToTime]? and (@steps[stepToTime].stage <= stage)
      maxMins = @steps[stepToTime].realMaxMins ? @steps[stepToTime].maxMins
      mins += maxMins
      stepToTime += 1
    mins
    
  shouldMoveOn: (step, lastStep, stage) ->
    #debug "shouldMoveOn", step, @firstForStages[stage], @step(step)?.stage, stage
    if (step >= 2) 
      return ((step < @firstForStages[stage]) or (lastStep is step and @step(step)?.stage < stage))
    return false

@PROCESS = new Process "Base",
  overview:
    suggestedMins: 0
    maxMins: 0.5
    stage: -1
    hit: off
    longName: "Overview"
    blurb: "See an outline of the experiment (this stage)."
,
  consent:
    suggestedMins: 0
    maxMins: 10
    stage: 0
    hit: off
    longName: "Consent"
    blurb: "Understand your rights, wait for the experiment to begin, and informed consent."
    prereqForNextStage: true
    beforeFinish: (cb) ->
      election = (Session.get 'election') and ELECTION
      options = _.pick(election, ['scenario', 'method'])
      options.method = nextMethodInWheel options.method
      Election.findAndJoin election._id, options, cb
, 
  scenario:
    suggestedMins: 1 
    maxMins: 2.5
    stage: 0
    hit: on
    longName: "Scenario"
    blurb: "Understand how much you and other voters will earn depending on which of the virtual candidates wins.\
 Also, wait until the experiment fills up before proceeding (a sound will play when ready)."
    popover: true
, 
  practice:
    suggestedMins: 1
    maxMins: 1.5
    stage: 1
    hit: on
    prereqForNextStage: true
    longName: "Election method practice"
    blurb: "Learn and practice the election method to be used."
    beforeFinish: (cb) ->
      election = (Session.get 'election') and ELECTION
      election.addVote VOTE.raw(), cb
, 
  results:
    suggestedMins: 0.5
    maxMins: 0.5
    stage: 2
    hit: on
    longName: "Practice results"
    blurb: "See results of the practice election: the winner and how much you would have been paid."
, 
  voting:
    suggestedMins: 0.5
    maxMins: 1
    stage: 2
    hit: on
    prereqForNextStage: true
    longName: "Voting round 1"
    blurb: "Vote. You will be paid based on results."
    beforeFinish: (cb) ->
      election = (Session.get 'election') and ELECTION
      election.addVote VOTE.raw(), cb
, 
  payouts:
    suggestedMins: 0.5
    maxMins: 0.5
    stage: 3
    hit: on
    payout: ->
      Template.oneRoundPay() #"$0-{{bonus 3}}"
    longName: "Payout round 1"
    blurb: "See results of the round 1 election: the winner and how much you will be paid. (Payments will arrive within 1 day)"
, 
  voting:
    suggestedMins: 0.5
    maxMins: 1
    stage: 3
    hit: on
    prereqForNextStage: true
    longName: "Voting round 2"
    blurb: "Vote. You will be paid again based on results."
    beforeFinish: (cb) ->
      election = (Session.get 'election') and ELECTION
      election.addVote VOTE.raw(), cb
, 
  payouts:
    suggestedMins: 0.5
    maxMins: 0.5
    stage: 4
    hit: on
    payout: ->
      Template.oneRoundPay() #"$0-{{bonus 3}}"
    prereq: -1 #a full set of voters must be through the step 1 earlier before anyone starts this step
    longName: "Payout round 2"
    blurb: "See results of the round 2 election: the winner and how much you will be paid. (Payments will arrive within 1 day)"
, 
  survey:
    suggestedMins: 2
    maxMins: 5
    stage: 4
    hit: on
    payout: ->
      Template.baseRate() #"{{baseRate}}"
    prereqForNextStage: false
    longName: "Survey"
    blurb: "4-5 simple questions each about:<ul><li>you (gender, country, etc)</li><li>the voting system you used (on a 0-7 scale)</li><li>your general comments about the experiment</li></ul>"
    beforeFinish: (cb) ->
      sendSurvey cb
, 
  debrief:
    suggestedMins: 0
    maxMins: 0.5
    stage: 4
    hit: on
    prereqForNextStage: true
    longName: "Debrief"
    blurb: "Thanks for participating, and a simple explanation of what we hope to learn from this study. Submit job and receive base pay."
,
  finished:
    suggestedMins: 999999
    maxMins: 999999
    stage: 5
    hit: on
    hide: true 
    longName: "Oops. You shouldn't see this..."
    blurb: "Lorem ipsum dolor sit amet."

    
    
@StepRecords = new Meteor.Collection 'stepRecords', null

StepRecords.allow
  insert: ->
    yes

if false ###############################
  if Meteor.isServer
    Meteor.publish 'stepRecords', (uid) ->
      StepRecords.find
        user: uid
    StepRecords.allow
      insert: ->
        true
  else  
    Meteor.autosubscribe ->
      if (Session.get 'router') and ROUTER?.current_page.get() is 'loggedIn'
        user = Meteor.user()
        if user?
          #Meteor.subscribe 'stepRecords', user._id
          0 #subscription to stepRecords is not needed, I think
          ############################

class @StepRecord extends VersionedInstance
  __name__: "StepRecord"
  
  collection: StepRecords
  
  constructor: (props) ->
    if Meteor.user? and not props?
      u = Meteor.user()
      step = Session.get 'step'
      props =
        voter: u?._id
        step: step
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
      debug "finished StepRecord."
      if Meteor.isClient and OPTIMIZE? #faster but harder to debug
        election = (Session.get 'election') and ELECTION
      else
        election = new Election Elections.findOne
          _id: @election
          
      if Meteor.isServer
        stepDoneBy = StepRecords.find(
              step: @step
              election: @election
            ).count()
            
        
        debug "It's been done by ", stepDoneBy
        election.stepsDoneBy[@step] = stepDoneBy
        
        if PROCESS.step(@step).prereqForNextStage
          debug "It's a prereq"
          if election.stage != PROCESS.step(@step).stage
            debug "...but stage isn't what it should be!!!!!!!!!!!", election.stage, PROCESS.step(@step).stage
          election.setTimerIf (PROCESS.step(@step + 1).stage), stepDoneBy
          if (stepDoneBy >= election.scen().numVoters() or #full scenario
                (election.stage > 0 and stepDoneBy >= election.voters.length)) #well at least everyone we have
            
            debug "save StepRecord finishStage"
            if election.stage >= 1
              election.finishStage()
              
            election.nextStage()
            
           
        #debug "save StepRecord 6", election
        election.save() 
          
      #move along if we can
      stageForNextStep = PROCESS.step(@step + 1).stage
      if election.stage >= stageForNextStep
        
        debug "stageForNextStep"
        @.constructor._moveOnServer(@step, @voter, yes)
          
      else
        
        debug "Time to wait...", election.stage, @step
        @.constructor._moveOnServer(@step, @voter, no)
          
    
    _moveOnServer: @static (step, voter, really) ->
      debug "moving on ", step, really, voter
      newStep = step + (if really then 1 else 0)
      if Meteor.isClient
        Session.set "step", newStep #ugly hack for greater responsiveness... but remember not to get step from Meteor.user()
        Session.set "stepLastStep", [newStep, step] #ugly hack for greater responsiveness... but remember not to get step from Meteor.user()
      else
        Meteor.users.update
          _id: voter
        ,
          $set:
            step: newStep
            lastStep: step
        ,
          multi: false
        , (r, e) ->
          debug "moved on", r, e
          
              
  moveOn: (really) ->
    @.constructor._moveOnServer @step, @voter, really
              
  finish: ->
    if @canFinish()
      now = new Date
      @done = now.getTime()
      @save =>
        debug "finished::::::::::::::::"#, @
        @finished()
        @after()
    else #can't finish
      #debug "can't finish stepRecord!"
  
  after: ->
    if PROCESS.step(@step).after?
      PROCESS.step(@step).after()
          
  canFinish: ->
    PROCESS.step(@step).canFinish @
  
StepRecord.admin()
#

          