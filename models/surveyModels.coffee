isNumber = (n) ->
  !isNaN(parseFloat(n)) && isFinite(n)

both = (validators...) ->
  (x) ->
    for validator in validators
      if not validator x
        return false
    return true
    
mandatory = (x) ->
  if x in ['', null, undefined]
    return false
  return true

optional = (x) ->
  true
    
class Question extends Field
  textTemplate: Template?.questionText
  
  constructor: (@text, validator) ->
    @displayOptions = new Reactive()
    super null, validator
    if Meteor.isClient and _.isString @text
      closuredText = @text
      @text = ->
        closuredText
    
  setName: (@name) ->
    yes
        
  getHtml: ->
    @wrapper((@textTag @text()) + @responseHtml())
  
  textTag: (text) ->
    @textTemplate
      text: text
      options: @displayOptions.get()
      
  wrapper: (beans) ->
    Template.questionWrapper
      text: beans
      mandatory: @mandatory
      
  responseHtml: ->
    "<!--NOT IMPLEMENTED-->"
    
class TextQuestion extends Question
  responseHtml: ->
    Template.answerText
      qName: @name
  
class NumberQuestion extends TextQuestion
  constructor: (@text, validator) ->
    super @text, (both validator, isNumber)

class TextboxQuestion extends Question
  responseHtml: ->
    Template.answerTextbox
      qName: @name
  
class RadioQuestion extends Question
  constructor: (@text, @options, validator) ->
    super @text, validator
    
  responseHtml: ->
    Template.answerRadio
      qName: @name
      optionInfos: @optionInfos()
      lowEnd: @lowEnd
      highEnd: @highEnd
      
  optionInfos: ->
    for oText, oNum in @options
      text: oText
      num: oNum
  
class ScaleQuestion extends RadioQuestion
  constructor: (@text, @lowEnd, @highEnd, validator) ->
    super @text, [0..5], validator
    
class MandatoryScaleQuestion extends ScaleQuestion
  mandatory: true
  #textTemplate: Template.mandatoryQuestionText
  
  constructor: (@text, @lowEnd, @highEnd) ->
    super @text, @lowEnd, @highEnd, mandatory
    
    
    
class Section extends Question
  constructor: (@text, @blurb, validator) ->
    super @text
    
  getHtml: ->
    Template.surveySection
      text: @text()
      blurb: @blurb
    
  wrapper: (beans) ->
    Template.nullWrapper
      text: beans

SurveyResponses = new Meteor.Collection 'surveyResponses', null

SurveyResponses.allow
  insert: (uid, doc) ->
    true

class SurveyResponse extends VersionedInstance
  
  collection: SurveyResponses
  
  questions = [
      yes and method: (new Section "Voting System", 
        "The questions in this section relate to the voting system itself, not the web design of this experiment. When answering them, imagine you had been voting using paper ballots.")
      yes and sysUnderstand: (new MandatoryScaleQuestion Template?.sysUnderstand, 
        "incomprehensible", "crystal clear")
      yes and sysEasy: (new MandatoryScaleQuestion Template?.sysEasy,#"How easy was it to figure out how you wanted to vote in {{methName}}?", 
        "impossible", "easy")
      yes and sysFair: (new MandatoryScaleQuestion Template?.sysFair,#"How fair did {{methName}} seem to you?", 
        "unfair", "fair")
      yes and sysFree: new TextboxQuestion Template?.sysFree #"Do you have any other comments about {{methName}}? (About the explanation, the system, whether you'd like to use it in real elections, or whatever)"
      yes and experiment: (new Section "Experiment", 
        "The following questions deal with the experiment. They may be used to fix the experiment for future runs. Since you have already participated in the experiment, you will not be allowed to participate again, so please be honest.")
      yes and expEasy: (new ScaleQuestion "What do you think of the web design and interface for this experiment?", 
        "bad/difficult/buggy", "good/easy/reliable")  
      yes and expBasePay: (new ScaleQuestion "What do you think about the base payment ($1.00) for participating in this experiment", 
        "much too low", "much higher than necessary")  
      yes and expBonusPay: (new ScaleQuestion "What do you think about the bonus payments ($0-$1.08) for participating in this experiment", 
        "much too low to be a good motivator", "much higher than necessary")  
      yes and expComments: new TextboxQuestion "Do you have any comments or suggestions? (problems you experienced, ideas how this experiment could work better, suggestions for further research, etc.)"  
      yes and notify: (new RadioQuestion "Do you wish to be notified (via Amazon Mechanical Turk) about the findings of this research?", 
        ["yes","no"])  
      yes and demographics: new Section "Demographics"
      yes and politics: (new RadioQuestion "How would you characterize your politics from left (liberal) to right (conservative)?", 
        ["Strongly left","Center-left","Center","Center-right","Strongly right"])
      yes and gender: (new RadioQuestion "Choose your gender.", ["male","female"])
      yes and country: new TextQuestion "What is your home country?"
      yes and education: (new RadioQuestion "What's the highest level in school you've reached?", 
        ["primary", "secondary/middle school", "high school", "some college/associate", "bachelors", "graduate"])
       ]
  
  questions: questions
    
  questionObject = _.extend {}, questions...
  
  for qName, q of questionObject
    q.setName qName
    
  _.extend questionObject,
    voter: ->
      if Meteor.isClient
        Meteor.user()._id
    election: ->
      if Meteor.isClient
        Session.get("election")._id
    method: ->
      if Meteor.isClient
        Session.get("method")
    
    
  @fields questionObject
  
  showErrors: ->
    badQs = @invalid()
    if badQs
      for questionAndName in @questions when question not in badQs
        for name, question of questionAndName
          question.displayOptions?.set({})
      for question in badQs
        question.displayOptions?.set 
          invalid: yes
      return "Please answer required questions."
    return no #no errors
  
  
SurveyResponse.admin()

console.log "creating @setupSurvey function"
@setupSurvey = ->
  window.SURVEY = new SurveyResponse
  
@sendSurvey = (cb) ->
  err = SURVEY.showErrors()
  if not err
    SURVEY.save cb
  else
    err = new Meteor.Error 0, err
    cb err, undefined #callback, as if there had been an error server-side
  
@surveyAnswer = (q, a) ->
  console.log "surveyAnswer", q, a
  SURVEY[q] = a

