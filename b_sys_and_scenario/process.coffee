nobind = (f) ->
  f.nobind = true
  f
  
class Step
  constructor: (@name, @num, options) ->
    _.extend @, options
    
class Process
  constructor: (@name, steps...) ->
    @steps = []
    for step in steps
      for name, options of step
        @steps.push new Step(name, @steps.length, options)
  
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
    prereq: 'consent' #a full set of voters must be through the foregoing
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
    longName: "Voting round 2"
    blurb: "Vote. You will be paid again based on results."
, 
  payouts:
    suggestedMins: 0.5
    maxMins: 1
    stage: 4
    longName: "Payout round 2"
    blurb: "See results of the round 2 election: the winner and how much you will be paid. (Payments will arrive within 1 day)"
, 
  survey:
    suggestedMins: 2
    maxMins: 10
    stage: 4
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
    
StepRecords = new Meteor.Collection 'stepRecords', null

class StepRecord extends StamperInstance
