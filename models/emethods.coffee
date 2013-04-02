nobind = (f) ->
  f.nobind = true
  f
  
class Method
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
  
makeMethods = (methods) ->
  madeMethods = {}
  for mName, methOpts of methods
    madeMethods[mName] = new Method mName, methOpts
  madeMethods
  
Methods = makeMethods
  approval:
    longName: "Approval Voting"
    actions:
      validVote: (numCands, vote) ->
        if vote.length > numCands then return false
        if (_(vote).without 0,1,undefined) isnt [] then return false
        true
        
      resolveVotes: (numCands, votes) ->
        console.log "resolveVotes", numCands, votes
        empty = (0 for cand in [1..numCands])
        counts = _.map (_.zip empty, votes...), (cvotes) ->
          _.reduce cvotes, (a,b) ->
            b ?= 0
            a + b
          , 0
        console.log "resolveVotes2", counts
        winners = []
        winningVotes = 0
        for count, cand in counts
          if count > winningVotes
            winners = [cand]
            winningVotes = count
          else if count is winningVotes
            winners.push cand
        [winners, counts]
        
  GMJ:
    longName: "Graduated Majority Judgment"
    actions:
      grades: ['F', 'D', 'C', 'B', 'A', 'AA']
    
      validVote: (numCands, vote) ->
        if vote.length > numCands then return false
        
        if (_(vote).without undefined, (_.range @grades.length)...) isnt [] then return false
        true
        
      resolveVotes: (numCands, votes) ->
        console.log "resolveVotes", numCands, votes
        nullVote = (0 for score in [1..@grades.length])
        voteTallies = for vote in votes
          for score in vote
            score ?= 0
            tally = nullVote.slice()
            tally[score] = 1
            tally
        tallies = _.map (_.zip voteTallies...), (cTallies) ->
          _.reduce cTallies, (tallyA, tallyB) ->
            _.map (_.zip tallyA, tallyB), (twoNums) ->
              twoNums[0] + twoNums[1]
          , nullVote
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
        [winners, scores]

  IRV:
    longName: "Instant Runoff Voting"
    actions:
      validVote: (numCands, vote) ->
        if vote.length > numCands 
          return false
        if (_.compact vote).length isnt (_.uniq _.compact vote).length
          return false
        for rank in vote
          if not (0 > rank >= -numCands)
            return false
        true
        
      resolveVotes: (numCands, votes) ->
        console.log "resolveVotes", numCands, votes
        ballots = for vote in votes
          ballot = []
          for rank, cand in vote
            ballot[rank] = cand
          ballot
        piles = ([] for cand in [1..numCands])
        winner = null
        numVotes = votes.length
        numVotes -= @sortAndElim ballots, piles
        round = 1
        while winner is null and numVotes
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
              console.log "IRV fuckup, everybody wins", piles, numVotes, round
              return [(cand for cand in [0..numCands - 1]), piles]
            loser = losers[Math.floor(Math.random() * losers.length)]
            resort = piles[loser]
            piles[loser] = round
            numVotes -= @sortAndElim resort, piles
          round += 1
        if winner 
          winners = [winner]
        else
          winners = (cand for cand in [0..(numCands - 1)])
        [winners, piles]
        
      sortAndElim: (votes, piles) ->
        elims = 0
        for vote in votes
          while vote.length and (not _.isArray piles[vote[0]])
            vote = vote.slice 1
          if vote.length
            piles[vote[0]].push vote
          else
            elims += 1
        elims    
        
  plurality:
    longName: "Plurality Voting"
    actions:
      validVote: (numCands, vote) ->
        if not vote?
          return true #abstaining is OK 
        if not (0 <= vote < numCands)
          return false
        true
            
      resolveVotes: (numCands, votes) ->
        empty = (0 for cand in [1..numCands])
        approvalBallots = for vote in votes
          ballot = empty.slice()
          if (0 <= vote < numCands)
            ballot[vote] = 1
          ballot
        Methods.approval.resolveVotes(numCands, approvalBallots)

  