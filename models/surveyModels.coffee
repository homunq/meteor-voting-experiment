isNumber = (n) ->
  !isNaN(parseFloat(n)) && isFinite(n)

class Question extends Field
  constructor: (@text, validator) ->
    super null, validator
    
  setName: (@name) ->
    if Meteor.is_client
      @makeHtml()
    
  makeHtml: ->
    @html = @wrapper((@textTag @text) + @responseHtml())
  
  textTag: (text) ->
    Template.questionText
      text: text
      
  wrapper: (beans) ->
    Template.questionWrapper
      text: beans
      
  responseHtml: ->
    "<!--NOT IMPLEMENTED-->"
    
class TextQuestion extends Question
  responseHtml: ->
    Template.answerText
      qName: @name
  
class NumberQuestion extends TextQuestion
  constructor: (@text) ->
    super @text, isNumber

class TextboxQuestion extends Question
  responseHtml: ->
    Template.answerTextbox
      qName: @name
  
class RadioQuestion extends Question
  constructor: (@text, @options) ->
    super @text
    
  responseHtml: ->
    Template.answerRadio
      qName: @name
      optionInfos: @optionInfos()
      
  optionInfos: ->
    for oText, oNum in @options
      text: oText
      num: oNum
  
class ScaleQuestion extends RadioQuestion
  constructor: (@text) ->
    super @text, _.range 8
    
class Section extends Question
  textTag: (text) ->
    Template.surveySection
      text: text
    

SurveyResponses = new Meteor.Collection 'surveyResponses', null

class SurveyResponse extends StamperInstance
  
  collection: SurveyResponses
  
  questions = [
      section1: new Section "Demographics"
      yes and gender: (new RadioQuestion "What is your gender?", ["male","female"])
      yes and country: new TextQuestion "What is your home country?"
      yes and politics: new RadioQuestion "How would you characterize your politics from left (liberal) to right (conservative)?", 3#["Strongly left","Center-left","Center","Center-right","Strongly right"]
      yes and education: new NumberQuestion "What's the highest grade in school you've completed (primary = 5, secondary/middle school=8, high school=12, college/bachelor's=16, master's=18, PhD=20)?"
      yes and section2: new Section "Voting System"
      yes and sysUnderstand: new ScaleQuestion "Considering the voting system you used: How easy to understand was it (from 0-incomprehensible to 7-crystal clear)?"
      yes and sysEasy: new ScaleQuestion "Considering the voting system you used: How easy to use was it (from 0-impossible to 7-easy)?"
      yes and sysFair: new ScaleQuestion "Considering the voting system you used: How fair did it seem to you (from 0-unfair to 7-fair)?"
      yes and sysFree: new TextboxQuestion "Considering the voting system you used: Do you have any other comments? (About the explanation, the system, whether you'd like to use it in real elections, or whatever)"
      yes and section3: (new Section "Experiment", "The following questions deal with the experiment. They may be used to fix the experiment for future runs. Since you have already participated in the experiment, you will not be allowed to participate again, so please be honest.")
      yes and basePay: new ScaleQuestion "What do you think about the base payment ($1.00) for participating in this experiment (from 0-much too low to 7-much higher than necessary)?"  
      yes and bonusPay: new ScaleQuestion "What do you think about the bonus payments ($0-$1.08) for participating in this experiment (from 0-much too low to be a good motivator to 7-much higher than necessary)?"  
      yes and comments: new TextboxQuestion "Do you have any comments or suggestions? (problems you experienced, ideas how this experiment could work better, suggestions for further research, etc.)"  
      yes and notify: (new RadioQuestion "Do you wish to be notified (via Amazon Mechanical Turk) about the findings of this research?", ["yes","no"])  
      yes and email: new TextQuestion "(beta testers ONLY; Mturkers should NOT see this question but if you somehow do don't fill it out) Please provide your email address."  
    ]
  
  questions: questions
    
  questionObject = _.extend questions...
  
  @fields questionObject
  
  for qName, q of questionObject
    q.setName qName
  
setupSurvey = ->
  window.SURVEY = new SurveyResponse
  
sendSurvey = (cb) ->
  SURVEY.save cb
  
surveyAnswer = (q, a) ->
  console.log "surveyAnswer", q, a
  SURVEY[q] = a

