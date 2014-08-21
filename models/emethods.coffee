(@_ = require "underscore") unless Meteor?
nobind = (f) ->
  f.nobind = true
  f
  
payKey = (payout) -> #handle silly issue with negative keys in honestVotes object literals
  if payout >= 0
    return payout
  ""+payout
  
class @Method
  constructor: (@name, options) ->
    #NOTE: all omethods are bound by default. I'm not sure that this is necessary but I'd sure rather debug the bugs from overdng this than from not doing it.
    @longName = options.longName
    for actname, action of options.actions
      if (not _.isFunction action) or action.nobind
        @[actname] = action
      else
        do (action) =>
          @[actname] = =>
            action.apply @, arguments
  
  honestVote: (payouts) ->
    @honestVotes[payKey(payout)] for payout in payouts
    
  resolveHonestVotes: (scenario, seed) ->
    @resolveVotes scenario, (@allHonestVotes scenario), seed
    
  allHonestVotes: (scenario) ->
    console.log "hv"
    for faction in scenario.vFactions()
      #console.log "@payoffsForFaction", faction, scenario.payoffsForFaction faction
      @honestVote (scenario.payoffsForFaction faction).payoffs
      
  breakTies: (scores, seed) ->
    if seed == 0
      return (score + i / 100 for i, score of scores)
    return (score + Math.random() for score in scores)
    
  normalize: (x) ->
    x ?= @bottom
    (x - @bottom) / (@top - @bottom)
    
  normSupportFor: (whom, ballotVote) ->
    @normalize ballotVote[whom]
      
      
  
makeMethods = (methods) ->
  madeMethods = {}
  for mName, methOpts of methods
    madeMethods[mName] = new Method mName, methOpts
  madeMethods
  
@Methods = makeMethods
  approval:
    longName: "Approval Voting"
    actions:
      top: 1
      bottom: 0
      validVote: (numCands, vote) ->
        if vote.length > numCands then return false
        if (_(vote).without 0,1,undefined) isnt [] then return false
        true
        
      resolveVotes: (scen, votes) ->
        numCands = scen.numCands()
        #debug "resolveVotes", numCands, votes
        empty = (0 for cand in [1..numCands])
        counts = _.map (_.zip empty, votes...), (cvotes) ->
          _.reduce cvotes, (a,b) ->
            b ?= 0
            a + b
          , 0
        #debug "resolveVotes2", counts
        winners = []
        winningVotes = 0
        for count, cand in counts
          if count > winningVotes
            winners = [cand]
            winningVotes = count
          else if count is winningVotes
            winners.push cand
        [winners, counts]
      
      honestVotes: [0,0,1,1]
    
  borda:
    longName: "Borda voting"
    
    actions:
      top: -1
      bottom: -4
      validVote: (numCands, vote) ->
        if vote.length > numCands 
          return false
        if (_.compact vote).length isnt (_.uniq _.compact vote).length
          return false
        for rank in vote
          if not (0 > rank >= -numCands)
            return false
        true
  
      resolveVotes: (scen, votes) ->
        numCands = scen.numCands()
        #debug "resolveVotes", numCands, votes
        sums = _.map (_.zip votes...), (scores) ->
          _.reduce scores, (tallyA, tallyB) ->
            (tallyA or 0) + (tallyB or 0) + (numCands)
          , 0
        winners = []
        winningScore = -1
        for score, cand in sums
          if score > winningScore
            winners = [cand]
            winningScore = score
          else if score is winningScore
            winners.push cand
        [winners, sums]
        
      honestVotes: 
        3:-1
        2:-2
        1:-2
        0:-3
        "-0.001":-4
          
  condorcet:
    longName: "Condorcet (pairwise) voting"
    actions:
      top: -1
      bottom: -4
      validVote: (numCands, vote) ->
        if vote.length > numCands 
          return false
        if (_.compact vote).length isnt (_.uniq _.compact vote).length
          return false
        for rank in vote
          if not (0 > rank >= -numCands)
            return false
        true
        
      resolveVotes: (scen, votes) ->
        numCands = scen.numCands()
        lastCand = numCands - 1
        #debug "resolveVotes", numCands, votes
        tallies = ((0 for cand in [0..lastCand]) for cand in [0..lastCand])
        for vote in votes
          for winCand in [0..lastCand]
            for loseCand in [0..lastCand]
              if not vote[loseCand]?
                vote[loseCand] = -999
              if vote[winCand] >= vote[loseCand] then tallies[winCand][loseCand] += 1
        minMargins = []
        beats = [] 
        for cand in [0..lastCand]
          minMargin = votes.length
          beats[cand] = []
          for otherCand in [0..lastCand]
            if otherCand is cand
              continue
            margin = tallies[cand][otherCand] - tallies[otherCand][cand]
            if margin > 0
              beats[cand].push otherCand
            if margin < minMargin
              minMargin = margin
          minMargins[cand] = minMargin
        winners = []
        winningScore = -(votes.length)
        for score, cand in minMargins
          if score > winningScore
            winners = [cand]
            winningScore = score
          else if score is winningScore
            winners.push cand
        debug "minMargins, beats, winners", minMargins..., beats..., winners...
        scores = for beat, b in beats
          "beats #{beat.length} others; worst margin #{minMargins[b]}"
        [winners, scores]
        
      honestVotes:
        3:-1
        2:-2
        1:-2
        0:-3
        "-0.001":-4
      
  GMJ:
    longName: "Graduated Majority Judgment"
    actions:
      top: 4
      bottom: 0
      grades: ['F', 'D', 'C', 'B', 'A']
    
      validVote: (numCands, vote) ->
        if vote.length > numCands then return false
        
        if (_(vote).without undefined, (_.range @grades.length)...) isnt [] then return false
        true
        
      resolveVotes: (scen, votes) ->
        numCands = scen.numCands()
        #debug "resolveVotes", numCands, votes
        tallies = for cand in [0...numCands]
          0 for score in [1..@grades.length]
        for vote in votes
          for score, cand in vote
            tallies[cand][score] += 1
        half = votes.length / 2
        scores = for tally in tallies
          cumulative = 0
          median = -1
          while median < 4 and cumulative < half
            median += 1
            cumulative += tally[median]
          lesses = cumulative - tally[median]
          mores = votes.length - cumulative
          score = median + ((mores - lesses) / (2 * tally[median]))
          score
        winners = []
        winningScore = -1
        for score, cand in scores
          if score > winningScore
            winners = [cand]
            winningScore = score
          else if score is winningScore
            winners.push cand
        [winners, (+score.toFixed(2) for score in scores)]
        
      honestVotes: 
        3:4
        2:3
        1:1
        0:0
        "-0.001":0
      
  IRV:
    longName: "Instant Runoff Voting"
    actions:
      top: -1
      bottom: -4
      validVote: (numCands, vote) ->
        if vote.length > numCands 
          return false
        if (_.compact vote).length isnt (_.uniq _.compact vote).length
          return false
        for rank in vote
          if not (0 > rank >= -numCands)
            return false
        true
        
      resolveVotes: (scen, votes) ->
        numCands = scen.numCands()
        #debug "resolveVotes", numCands, votes
        ballots = for vote in votes
          ballot = []
          for rank, cand in vote
            ballot[-rank - 1] = cand
          ballot
        piles = ([] for cand in [1..numCands])
        winner = null
        numVotes = votes.length
        numVotes -= @sortAndElim ballots, piles
        round = 1
        losers = [] #in case there are no votes
        while (winner is null) and numVotes
          losers = []
          losingScore = winningScore = numVotes/2
          for pile, cand in piles
            if _.isArray pile
              if pile.length is 0
                piles[cand] = 0
              else
                if pile.length > winningScore
                  winner = cand
                if pile.length < losingScore
                  losingScore = pile.length
                  losers = [cand]
                if pile.length is losingScore
                  losers.push cand
          if winner is null
            if losers.length is 0
              debug "IRV fuckup, everybody wins", piles, numVotes, round
              return [(cand for cand in [0..numCands - 1]), piles]
            loser = losers[Math.floor(Math.random() * losers.length)]
            resort = piles[loser]
            piles[loser] = round
            numVotes -= @sortAndElim resort, piles
          round += 1
        if winner isnt null
          winners = [winner]
        else
          winners = (cand for cand in [0..(numCands - 1)] when cand not in losers)
        shortpiles = for pile in piles
          if _.isArray(pile)
            1 for vote in pile
          else
            pile
        [winners, shortpiles]
        
      sortAndElim: (votes, piles) ->
        elims = 0
        for vote in votes
          while vote.length and (not _.isArray piles[vote[0]])
            vote = vote.slice 1
          if vote.length
            piles[vote[0]].push vote
          else
            elims += 1
        #debug "sortAndElim", votes, piles
        elims    
        
      honestVotes:
        3:-1
        2:-2
        1:-2
        0:-3
        "-0.001":-4
     
  MAV:
    longName: "Majority Approval Voting"
    actions:
      top: 4
      bottom: 0
      grades: ['F', 'D', 'C', 'B', 'A']
    
      validVote: (numCands, vote) ->
        if vote.length > numCands then return false
        
        if (_(vote).without undefined, (_.range @grades.length)...) isnt [] then return false
        true
        
      resolveVotes: (scen, votes) ->
        numCands = scen.numCands()
        #debug "resolveVotes", numCands, votes
        nullVote = (0 for score in [1..@grades.length])
        voteTallies = for vote in votes
          for cand in [0..scen.numCands()]
            score = vote[cand] or 0
            tally = nullVote.slice()
            tally[score] = 1
            tally
        tallies = _.map (_.zip voteTallies...), (cTallies) ->
          _.reduce cTallies, (tallyA, tallyB) ->
            _.map (_.zip tallyA, tallyB), (twoNums) ->
              twoNums[0] + twoNums[1]
          , nullVote
        half = votes.length / 2
        fakeLesses = half - votes.length / 10
        scores = for tally in tallies
          cumulative = 0
          median = -1
          while median < 4 and cumulative < half
            median += 1
            cumulative += tally[median]
          lesses = cumulative - tally[median]
          mores = votes.length - cumulative
          if (mores > 0) or (lesses > 0) #when a whole faction gives the same number, just use that.
            lesses = fakeLesses
          score = median + ((mores - lesses) / (2 * (votes.length - mores - lesses)))
          score
        winners = []
        winningScore = -1
        for score, cand in scores
          if score > winningScore
            winners = [cand]
            winningScore = score
          else if score is winningScore
            winners.push cand
        [winners, (+score.toFixed(2) for score in scores)]
        
      honestVotes: 
        3:4
        2:3
        1:1
        0:0
        "-0.001":0
   
  plurality:
    longName: "Plurality Voting"
    actions:
      top: 1
      bottom: 0
      
      normSupportFor: (whom, ballotVote) ->
        if whom is ballotVote then 1 else 0
        
      validVote: (numCands, vote) ->
        if not vote?
          return true #abstaining is OK 
        if not (0 <= vote < numCands)
          debug "invalid plurality vote:", vote, numcands
          return false
        true
            
      resolveVotes: (scen, votes) ->
        numCands = scen.numCands()
        empty = (0 for cand in [1..numCands])
        approvalBallots = for vote in votes
          ballot = empty.slice()
          if (0 <= vote < numCands)
            ballot[vote] = 1
          ballot
        Methods.approval.resolveVotes scen, approvalBallots

      honestVote: (payouts) ->
        bestPay = -1
        vote = null
        for payout, i in payouts
          if payout > bestPay
            vote = i
            bestPay = payout
        vote
    
  score:
    longName: "Score Voting"
    actions:
      top: 10
      bottom: 0
      scores: [0..10]
    
      validVote: (numCands, vote) ->
        if vote.length > numCands then return false
        
        if (_(vote).without undefined, (_.range @scores.length)...) isnt [] then return false
        true
        
      resolveVotes: (scen, votes) ->
        numCands = scen.numCands()
        debug "resolveVotes", numCands, votes
        sums = _.map (_.zip votes...), (scores) ->
          _.reduce scores, (tallyA, tallyB) ->
            (tallyA or 0) + (tallyB or 0)
          , 0
        winners = []
        winningScore = -1
        for score, cand in sums
          if score > winningScore
            winners = [cand]
            winningScore = score
          else if score is winningScore
            winners.push cand
        [winners, sums]
        
      honestVotes: 
        3:10
        2:7
        1:3
        0:0
        "-0.001":0
      
  SODA:
    longName: "SODA voting"
    
    
    actions:
      top: 1
      bottom: 0
      validVote: (numCands, vote) ->
        if vote.length > (numCands+1) then return false
        if (_(vote).without 0,1,undefined) isnt [] then return false
        true
        
      processCandInfo: (candInfo) ->
        if true # candInfo.length isnt 4
          candInfo.push
            color: "#000000"
            myPayoff: " "
            name: "DND (Do Not Delegate)"
            num: candInfo.length
            checkText: " "
            bgColor: "#aaa"
        #if candInfo.length is 5
        #  candInfo.splice(3,1)
        else
          candInfo[3].name = candInfo[3].name + " (No delegation)"
        candInfo
        
      resolveVotes: (scen, votes, seed) ->
        numCands = scen.numCands()
        approvals = (0 for cand in [0..numCands - 1])
        delegations = (0 for cand in [0..numCands - 1])
        for vote in votes
          multiApprovals = 0
          for line, l in vote
            if line
              if l < numCands
                approvals[l] += 1
              multiApprovals += 1
          if multiApprovals is 1
            delegations[vote.indexOf 1] += 1
        brokenApprovals = @breakTies(approvals,seed)
        
        [winner, totals, delegations] = @recursiveWinner brokenApprovals, delegations, scen.prefs()
        scores = for total, t in totals
          "#{approvals[t]} + #{Math.round(total - brokenApprovals[t])}"
        [winner, scores]
          
      recursiveWinner: (approvals, delegations, prefs) ->
        #returns [winner, totals, [[delegator, numassigns], ...]]
        noDelegations = ((_(delegations).without 0).length is 0)
        filteredApprovals = for approval, i in approvals
          if (delegations[i] or noDelegations) #if there are no delegations, we just want to get the winner to return it.
            approval  
          else 
            0
        delegator = @winnerOf filteredApprovals
        if noDelegations
          return [[delegator], approvals, []]
          
        newDelegations = delegations.slice()
        newDelegations[delegator] = 0
        subWinners = for deleLen in [0..(prefs[delegator].length - 2)]
          newApprovals = approvals.slice()
          for assignTo in prefs[delegator].slice 1, deleLen+1
              #console.log "plus", assignTo, delegations[delegator]
              newApprovals[assignTo] += delegations[delegator]
          #console.log "newApprovals", newApprovals, deleLen, prefs[delegator]
          @recursiveWinner newApprovals, newDelegations, prefs
        winnerIndex = 999
        for subWinnerData, numSubAssigns in subWinners by -1
          [subWinner, totals, delegations] = subWinnerData
          subWinnerIndex = _(prefs[delegator]).indexOf(subWinner[0])
          if (((subWinnerIndex >= 0) and (subWinnerIndex <= winnerIndex)) or
            ((numSubAssigns is 0) and (winnerIndex is 999)))
              winnerIndex = subWinnerIndex
              winner = subWinner[0]
              numAssigns = numSubAssigns
              laterDelegations = delegations
              totals = totals
          #console.log "hi2", subWinner, winner, subWinnerIndex, numSubAssigns
        debug "totals", (totals for [subWinner, totals, delegations] in subWinners)...
        #console.log "delegator is", delegator, filteredApprovals, noDelegations, delegations
        debug "delegator, winner, numAssigns, totals, laterDelegations", delegator, winner, numAssigns, totals, laterDelegations
        return [[winner], totals, [[delegator, numAssigns]].concat laterDelegations]
        
      winnerOf: (scores) ->
        best = bestI = undefined
        for score, i in scores
          if not (score < best)
            best = score
            bestI = i
        return bestI
        
      honestVotes:
        3:1
        2:0
        1:0
        0:0
        "-0.001":0
        
#expose for Node testing        
exports = Methods unless Meteor?

@METHOD_WHEEL = ["approval", "borda", "condorcet", "SODA", "plurality", "MAV", "IRV", "score"]
@METHOD_WHEEL = _.sample(METHOD_WHEEL, 999) #shuffle

@nextMethodInWheel = (method) ->
  i = METHOD_WHEEL.indexOf method
  return METHOD_WHEEL[(i + 1) % METHOD_WHEEL.length]
  
