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
    
class @Question extends Field
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
    
class @TextQuestion extends Question
  responseHtml: ->
    Template.answerText
      qName: @name
  
class @NumberQuestion extends TextQuestion
  constructor: (@text, validator) ->
    super @text, (both validator, isNumber)

class @TextboxQuestion extends Question
  responseHtml: ->
    Template.answerTextbox
      qName: @name
  
class @RadioQuestion extends Question
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
  
class @ScaleQuestion extends RadioQuestion
  constructor: (@text, @lowEnd, @highEnd, validator) ->
    super @text, [0..5], validator
    
class @MandatoryScaleQuestion extends ScaleQuestion
  mandatory: true
  #textTemplate: Template.mandatoryQuestionText
  
  constructor: (@text, @lowEnd, @highEnd) ->
    super @text, @lowEnd, @highEnd, mandatory
    
    
    
class @Section extends Question
  constructor: (@text, @blurb, validator) ->
    super @text
    
  getHtml: ->
    Template.surveySection
      text: @text()
      blurb: @blurb
    
  wrapper: (beans) ->
    Template.nullWrapper
      text: beans

@SurveyResponses = new Meteor.Collection 'surveyResponses', null

SurveyResponses.allow
  insert: (uid, doc) ->
    true

class @SurveyResponse extends VersionedInstance
  
  collection: SurveyResponses
  
  questions = [
      yes and method: (new Section "Voting System", 
        """The questions in this section relate to the voting system itself, not the web design of this experiment
        or the payoff structure. 
        When answering them, <strong>imagine</strong> you had been voting using <strong>paper ballots</strong> in a
        normal political election.""")
      yes and sysUnderstand: (new MandatoryScaleQuestion Template?.sysUnderstand, 
        "incomprehensible", "crystal clear")
      yes and sysEasy: (new MandatoryScaleQuestion Template?.sysEasy,#"How easy was it to figure out how you wanted to vote in {{methName}}?", 
        "impossible", "easy")
      yes and sysFair: (new MandatoryScaleQuestion Template?.sysFair,#"How fair did {{methName}} seem to you?", 
        "unfair", "fair")
      yes and sysImportant: (new RadioQuestion "Which of the above characteristics would you consider most <strong>important</strong> for a country's voting system?",#"How fair did {{methName}} seem to you?", 
        ["understandable","easy to vote","fair","all equally important","other (explain below)"])
      yes and sysFree: new TextboxQuestion Template?.sysFree #"Do you have any other comments about {{methName}}? (About the explanation, the system, whether you'd like to use it in real elections, or whatever)"
      yes and experiment: (new Section "Experiment", 
        """The following questions deal with the experiment. They may be used to fix the experiment for future runs. 
        Since you have already participated in the experiment, 
        you will not be allowed to participate again, so <strong>please be honest</strong>.""")
      yes and expEasy: (new ScaleQuestion """What do you think of the <strong>web design and interface</strong> 
      for this experiment?""", 
        "bad/difficult/buggy", "good/easy/reliable")  
      yes and expBasePay: (new ScaleQuestion Template?.expBasePay, 
        "much too low", "much higher than necessary")  
      yes and expBonusPay: (new ScaleQuestion Template?.expBonusPay, 
        "much too low to be a good motivator", "much higher than necessary")  
      yes and politics: (new ScaleQuestion """What is two plus two? (If you get this one wrong, we'll know
        you're not paying attention)""", 
        "lower", "higher")
      yes and expComments: new TextboxQuestion """Do you have any comments or suggestions? (problems you experienced, 
        ideas how this experiment could work better, suggestions for further research, etc.)""" 
      yes and notify: (new RadioQuestion "Do you wish to be notified (via Amazon Mechanical Turk) about the findings of this research?", 
        ["yes","no"])  
      yes and demographics: new Section "Demographics"
      yes and politics: (new RadioQuestion "How would you characterize your politics from left (liberal) to right (conservative)?", 
        ["Strongly left","Center-left","Center","Center-right","Strongly right"])
      yes and politics: (new RadioQuestion "How often do you vote?", 
        ["Every election","Most elections","Occasionally (every 2-4 years)","Rarely","Never","I'm not allowed to"])
      yes and politics: (new RadioQuestion "Where did you grow up? <em>(Choose the first option which applies)</em>", 
        ["USA","Anglophone country","Latin America","Africa/Middle East","Asia/Pacific","Europe","Not on Earth"])
      yes and gender: (new RadioQuestion "Choose your gender.", ["male","female"])
      yes and education: (new RadioQuestion "What's the highest level in school you've reached?", 
        ["primary", "secondary/middle school", "high school", "some college/associate", "bachelors", "graduate"])
      yes and age: (new RadioQuestion "How old are you?", 
        ["0-17", "18-21", "22-29", "30-39", "40-59", "60+"])
       ]
  
  questions: questions
    
  questionObject = _.extend {}, questions...
  
  for qName, q of questionObject
    q.setName qName
    
  if Meteor.isClient
    Deps.autorun ->
      _.extend questionObject,
        voter: ->
          Meteor.user()?._id
        election: ->
          Session.get("election")?._id
        method: ->
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

debug "creating @setupSurvey function"
@setupSurvey = ->
  #Note: This is getting called redundantly when survey answers are repainted. Tolerable for now but yucky.
  debug "@setupSurvey"
  if not window.SURVEY?
    window.SURVEY = new SurveyResponse
  
@sendSurvey = (cb) ->
  err = SURVEY.showErrors()
  if not err
    SURVEY.save cb
  else
    err = new Meteor.Error 0, "surveyError", err
    cb err, undefined #callback, as if there had been an error server-side
  
@surveyAnswer = (q, a) ->
  debug "surveyAnswer", q, a
  SURVEY[q] = a

