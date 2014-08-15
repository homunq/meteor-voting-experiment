
@USERS = Meteor.users

@blurbConditions =
  none: 3 #2
  stratBlurb1: 2 #1
  stratBlurb2: 2 #1
  
@payoffConditions = 
  noAverages: 3 #1
  averages: 4 #1

@generateCondition = (probs) ->
  conditionList = []
  for key, val of probs
    for i in [0...val]
      conditionList.push(key)
  _.sample conditionList
  
@generatePayoffCondition = (faction, election) ->
  generateCondition @payoffConditions

@generateBlurbCondition = (faction, election) ->
  generateCondition @blurbConditions
  

class @MtUser extends VersionedInstance
  __name__: "User"
    
  collection: Meteor.users
  
  _loose: yes
  
  @fields
    username: undefined
    token: undefined
    eid: undefined
    watcher: undefined
    step: undefined
    lastStep: undefined
    faction: undefined
    blurbCondition: undefined
    payoffCondition: undefined
    turkSubmitTo: undefined
    stickyWorkerId: undefined
    workerId: undefined
    assignmentId: undefined
    stickyAssignmentId: undefined
    hitId: undefined
    nonunique: undefined
    submitted: false
    _wasntMe: undefined
    _paid: undefined    
    
  
  @register
    setParams: (params) ->
      debug "user.setParams started", params
      if @workerId
        if @workerId is params.workerId
          #debug "(re-adding same workerId, ignored)"
          return
        #debug "You sneaky little thang, using the same browser with several workerIds."
        #debug "I should report you but I won't because you're probably me."
      
      if params.workerId
        likeMe = Meteor.users.findOne
          stickyWorkerId: params.workerId
          step:
            $gt: 2
        @nonunique = (likeMe and (likeMe._id isnt @_id))
        if @_wasntMe or likeMe?._wasntMe
          @_wasntMe = true
          @nonunique = false
        if @nonunique and @eid
          @election().userNonunique @id
            
        @stickyWorkerId = params.workerId
      @workerId = params.workerId
      @assignmentId = params.assignmentId
      if params.assignmentId isnt 'ASSIGNMENT_ID_NOT_AVAILABLE'
        @stickyAssignmentId = params.assignmentId
      @hitId = params.hitId
      @turkSubmitTo = params.turkSubmitTo
      
      @save =>
        debug "setParams complete"
  
    wasntMe: (yesItWas) ->
      #debug "Setting nonunique for testing.", !yesItWas
      wasntUnique = @nonunique
      @nonunique = no
      @_wasntMe = !yesItWas
      if @workerId
        dupeWorkers = Meteor.users.find
          workerId: @workerId
        dupeWorkers = dupeWorkers.fetch()
        for dupeWorker in dupeWorkers
          dupeWorker = new MtUser dupeWorker
          dupeWorker._wasntMe = true
          dupeWorker.save()
      @save()
      if @eid and wasntUnique and (@step >= 2) and Meteor.isServer
        Election.join @eid
    
    setPaid: ->
      @paid = yes
      @save()
      
      
    serverAnswers: ->
      
      SURVEY = new SurveyResponse
      answers = SurveyResponses.findOne
        voter: @_id
      debug answers
      for question in SURVEY.questions
        answers[Object.keys(question)[0]]
        
    serverSubmittable: ->
      if Meteor.isServer
        debug "serverSubmittable"
        if @submitted
          debug "wasntMe?", @
          if @_wasntMe
            return "wasntMe"
          return no
        @submitted = yes
        @save()
        if not @workerId
          return no
        similar = USERS.find
          stickyWorkerId: @workerId
          submitted: yes
        if similar.count() isnt 1
          debug "wasntMe?", @
          if @_wasntMe
            return "wasntMe"
          return no
        similar = USERS.find
          workerId: @workerId
          submitted: yes
        if similar.count() isnt 1
          return no
        return IS_LEGIT
     
    forElection: @static (eid) ->
      election = Elections.findOne
        _id: eid
      #debug "forElection", eid, election?.voters, Meteor.users.findOne({_id:election?.voters[0]})
      if election
        return (Meteor.users.findOne({_id:vid}) for vid in election.voters)
      
        
  election: ->
    new Election Elections.findOne
      _id: @eid
  
  votes: ->
    votes = Votes.find
      voter: @_id
    votes = votes.fetch()
    #debug "hmmmmmmmmmmmmmmmmmmmmmmmm:", @_id, votes
    _.unique votes, false, (vote) ->
      #debug "unique vote?", vote
      "#{vote.election} #{vote.stage}"
        
  centsDue: ->
    #debug "centsDue wtf", @, @votes
    if @_paid
      return 0
    cents = 0
    for vote in @votes()
      #debug "vote is", vote
      if vote.stage in [2,3]
        outcome = Outcomes.findOne
          election: vote.election
          stage: vote.stage
        #debug "vote outcome", outcome
        if outcome
          outcome = new Outcome outcome
          cents += outcome.payFactionCents @faction
    cents
    
  numVoted: ->
    steps = StepRecords.find
      voter: @_id
    votes = Votes.find
      voter: @_id
    
    result = [steps.count(), votes.count()]
    #debug result
    result

MtUser.admin()
    
@getUser = -> 
  (new MtUser Meteor.user())
                
@wasntMe = ->
  getUser().wasntMe()

if Meteor.isServer
  userFields = {}
  for k, v of MtUser.prototype._fields
    userFields[k] = 1
  debug "server publishing userData!"#, userFields# server
  Meteor.users.allow
    update: (uid, doc) ->
      debug "updating user", uid, doc
      doc._id is uid
  Meteor.publish "userData", ->
    if @userId
      debug "publishing uid", @userId #, Meteor.users.findOne({_id:@userId}).step
      return Meteor.users.find
        _id: @userId
      ,
        fields: userFields
  
    else
      @ready()
    