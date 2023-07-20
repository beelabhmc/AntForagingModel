extensions [profiler]

;; Two Nest Updates
;; X  at the beginning create two nests with two different populations
;; X  each ant will need to know which nest it is from
;; X  ants see other nests as food sources
;; X  at each food source, ants return to the closest nest and join that nest with a certain probability
;; X  keep track of amount of food in each nest. Ants can only take food if there is food to take
;; X  set food source and nest locations using absolute coordinates
;; X  orient ants towards food source or nest they returned from

;; Realism Updates
;; X  food sources have rate of food production. ants bring back constant amount of food if they can
;; X  nest consumption proportional to population
;; X  nest and food sources have max amount of food they can store
;;    lets get everything in the right units
;;      X  30mx30m area
;;      X  ants move @ 1cm/s -> each tick is 100 seconds, should reference everything else from this (mainly food production), nothing should be larger than one patch for the most part
;;      X  maximum trail length possible to maintain should be about 25m (sandor data, he probably got that figure from somewhere else)
;;      X  make nest maximum proportional to the amount of nests in the ant and the load per ant (from lecheval)
;; X  make it so that ants will return from other nest empty-handed if there's no food there instead of continuing on to search at other food sources and then joining the new nest
;;    ants need to return to a nest following the same trails they used to get there --> nest stack?
;;       if an ant passes through/near a nest, add that to the stack
;;       on the return trip, the ants pops off the stack and goes to that nest until it gets home


;; Quality of life updates
;; X  food and nest labels for ease of use
;; X  trail strength monitor (ants on trail / distance)
;; X  get food source with the strongest and weakest trails and monitor
;;    moving averages?
;; >  network efficiency plot
;; >      all vertices
;; >      nests only
;; >  network robustness plot                       Seems it would be best to use ready-made functions and do all of this in R or python
;; >      all vertices                                 Would be good to figure out how we convert the data we have into a graph though
;; >      nests only


;; Experiment Updates
;; X  Function to set a food source's production rate by number
;; X  Function to report a food source's production rate by number
;; X  Capability to set a start and stop time for exclusion and make that exclusion happen
;; X  add directionality to internest strengths
;; X  Need to make it so that the strength between a nest and a food source is only counting ants that will actually return to that food source
;;     X Trail strengths sum across all nests, we have to interpret which nest they are actually going to / coming from
;;     X Need a function that returns the distance from a point to the nearest nest
;; X  When excluding the weakest trail, it needs to be a trail that is actually being used
;;     X Need to be able to set a threshold for "in use", which should clearly be 2.5 ants / m <--> "10 for 400"

;; Major overhaul, everything that can be is list-based now.
;;    It does seem to run slower but it is significantly easier to modify things now


patches-own [
  chemical1
  chemical2
  chemical3
  chemical4
  chemical5
  chemical             ;; total amount of chemical
  chemicalnest

  nest-number
  source-number
]

turtles-own [
                       ;;                   statuses: "at nest", "return-from-1", "return-from-2", "return-from-3", "return-from-4", "return-from-5", "foraging-for-1", "foraging-for-2", "foraging-for-3", "foraging-for-4", "foraging-for-5", "foraging"
                       ;; corresponds with status:    0    ,       10        ,       20       ,        30      ,        40      ,     50         ,        1        ,         2       ,         3,      ,       4,        ,        5,       ,    99
  status            ;; variable telling the turtle what it is currently doing (integer form)
                       ;;      status key is listed above with status variable
  prevfood             ;; variable holding the information for which food source each ant has been to most recently, 1 indexed with positive indicating food sources and negative indicating nests
  nest                 ;; variable holding which nest each turtle is from
]

;;;;;;;;;;;;;;;;;;;;;;;;
;;; Setup procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;

globals [
  excluded-source-production

  source-locs
  source-food

  nest-locs
  nest-food
  nest-maxs

  food-productions
  food-maxs
]


to setup
  clear-all

  setup-patches
  set food-productions (read-from-string food-production)
  set food-maxs        (read-from-string food-max)

  set-default-shape turtles "bug"
  let pop (read-from-string population)
  (foreach (n-values (length pop) [i -> i]) pop
    [[i p] ->
      create-turtles p [
       set size 0.28
       set status 0
       set nest i
       set color red
       let loc (item i nest-locs)
       let x (first loc)
       let y (last loc)
       setxy x y
       right random 360
      ]
  ])

  reset-ticks
end

to setup-patches
  ask patches [
    set nest-number -1
    set source-number -1

    setup-nests
    setup-food

    recolor-patch
  ]
end

to setup-nests  ;; patch procedure
  set nest-locs (read-from-string nest-loc)
  set nest-food  (n-values (length nest-locs) [0])
  set nest-maxs (n-values (length nest-locs) [0])

  (foreach (n-values (length nest-locs) [i -> i]) (nest-locs)
    [[i loc] ->
      let x (first loc)
      let y (last loc)
      if (distancexy x y < 1)[
        set nest-number i
      ]
      ask patch (x + 5) y [set plabel "N" set plabel-color violet]
      ask patch (x + 10) y [set plabel i set plabel-color violet]
    ]
  )
end


to setup-food  ;; patch procedure
  set source-locs (read-from-string source-loc)
  set source-food (read-from-string food-init)

  (foreach (n-values (length source-locs) [ i -> i ]) (source-locs)
    [[i loc] ->
      let x (first loc)
      let y (last loc)
      if (distancexy x y < 1)[
        set source-number i
      ]
      ask patch (x + 5) y [set plabel "T" set plabel-color 66]
      ask patch (x + 10) y [set plabel i set plabel-color 66]
    ]
  )
end

to recolor-patch  ;; patch procedure
  ;; give color to nest and food sources
  (ifelse nest-number >= 0 [
      set pcolor violet
    ]
    source-number >= 0 [
      set pcolor 66
    ][
      set pcolor scale-color magenta (chemical1 + chemical2 + chemical3 + chemical4 + chemical5 + chemicalnest) 0.05 20
   ])
end

;;;;;;;;;;;;;;;;;;;;;
;;; Go procedures ;;;
;;;;;;;;;;;;;;;;;;;;;

to go  ;; forever button
  ask turtles [
    (ifelse
      color = red [ ; foraging
         if nest-number >= 0[
           set status 0
         ]
         look-for-food
      ]
      color = blue [ ; returning with food
        return-to-nest
      ]
      color = yellow [ ; returning without food
        return-to-nest-no-food
      ])
    wiggle
    fd 1
  ]

  ; don't think I can do this with an array :(
  diffuse chemical1 (diffusion-rate / 100)
  diffuse chemical2 (diffusion-rate / 100)
  diffuse chemical3 (diffusion-rate / 100)
  diffuse chemical4 (diffusion-rate / 100)
  diffuse chemical5 (diffusion-rate / 100)
  diffuse chemicalnest (diffusion-rate / 100)

  ask patches [
    set chemical1 chemical1 * (100 - evaporation-rate) / 100  ;; slowly evaporate chemical
    set chemical2 chemical2 * (100 - evaporation-rate) / 100
    set chemical3 chemical3 * (100 - evaporation-rate) / 100
    set chemical4 chemical4 * (100 - evaporation-rate) / 100
    set chemical5 chemical5 * (100 - evaporation-rate) / 100
    set chemicalnest chemicalnest * (100 - evaporation-rate) / 100
    set chemical chemical1 + chemical2 + chemical3 + chemical4 + chemical5 + chemicalnest
    recolor-patch
  ]

  ; Update food stores, either producing them for sources or consuming them in nests
  (foreach (n-values (length source-locs) [i -> i])
    [[i] ->
      set source-food (replace-item i source-food ((item i source-food) + (item i food-productions)))
      if item i source-food > item i food-maxs [
        set source-food (replace-item i source-food (item i food-maxs))
      ]
   ])

  (foreach (n-values (length nest-locs) [i -> i])
    [[i] ->
      set nest-food (replace-item i nest-food ((item i nest-food) - (count turtles with [nest = i]) * food-consumption))
      if item i nest-food < 0 [
          set nest-food (replace-item i nest-food 0)
      ]
      set nest-maxs (replace-item i nest-maxs (storage-factor * (count turtles with [nest = i]) * carrying-capacity))
  ])

  ;Exclusion Experiment
  if exclude? [
    (ifelse
      ticks = exclusion-start [exclude]
      ticks = exclusion-stop [include]
    )
  ]

  tick
end

to return-to-nest  ;; turtle procedure
  ifelse nest = nest-number [
    ; back in foraging mode
    set color red
    ; drop off food
    set nest-food (replace-item nest nest-food (item nest nest-food + carrying-capacity))
    if item nest nest-food > item nest nest-maxs [
      set nest-food (replace-item nest nest-food (item nest nest-maxs))
    ]
    ; reset location to center of nest
    let loc item nest nest-locs
    let x first loc
    let y last loc
    setxy x y

    ;set heading to be towards most recent food source with a certain probability
    if random(100) / 100 < fprob [
      (ifelse
      prevfood > 0 [
        set loc item (prevfood - 1) source-locs      ; minus 1 because prevfood is 1 indexed
        set x first loc
        set y last loc
        set heading 180 - atan (xcor - x) (ycor - y)
      ][
        let prevnest prevfood * -1
        set loc item (prevnest - 1) nest-locs        ; minus 1 because prevnest is 1 indexed
        set x first loc
        set y last loc
        set heading 180 - atan (xcor - x) (ycor - y)
      ])
    ]

    set status 0
  ][
    (ifelse
      prevfood = 1 [set chemical1 (chemical1 + base-pheromone * pheromone-1)]
      prevfood = 2 [set chemical2 (chemical2 + base-pheromone * pheromone-2)]
      prevfood = 3 [set chemical3 (chemical3 + base-pheromone * pheromone-3)]
      prevfood = 4 [set chemical4 (chemical4 + base-pheromone * pheromone-4)]
      prevfood = 5 [set chemical5 (chemical5 + base-pheromone * pheromone-5)]
      prevfood < 0 [set chemicalnest (chemicalnest + base-pheromone * pheromone-nest)]
     )
     uphill-nest-scent
  ]
end

to return-to-nest-no-food  ;; turtle procedure
  ifelse nest = nest-number [
    ; reset location to center of nest
    let loc item nest nest-locs
    let x first loc
    let y last loc
    setxy x y

    ; spin around
    right random 360

    ; head out again
    set color red
    set status 0
  ][
    ; go home
    uphill-nest-scent
  ]
end

to look-for-food  ;; turtle procedure
  ; if we find food
  (ifelse
  source-number >= 0 [
    ; turn around
    rt 180
    set prevfood source-number + 1   ; plus 1 because 1-indexed
    set status 10 * prevfood
    ifelse (item source-number source-food) > carrying-capacity [
      set color blue
      set source-food (replace-item source-number source-food (item source-number source-food - carrying-capacity))
    ][
      set color yellow

    ]
    stop
  ]
  ; if we find another nest
  (nest-number >= 0) and (nest-number != nest) [
    ; return home, taking food if we can
    rt 180
    set prevfood -1 * (nest-number + 1) ; plus 1 because 1-indexed
    set status -10 * (nest-number + 1)
    ifelse (item nest nest-food) > carrying-capacity [
      set nest-food (replace-item nest nest-food (item nest nest-food - carrying-capacity))
      set color blue
    ][
      set color yellow
    ]
    stop
  ]
  ; if we are following a trail, update our status
  chemical >= 0.05 [
    let chemicals (list chemical1 chemical2 chemical3 chemical4 chemical5 chemicalnest)
    let max-chemical position (max chemicals) chemicals
    set status max-chemical + 1 ; plus 1 because 1-indexed
    if status = 6 [
      set status -1
    ]
    move-around-rank-edge
  ]
  ; if we aren't following a trail, turn around and return home with a certain probability
  [
   if (random-float 1 > prob) [
     set color yellow
     set status 99
   ]
  ])
  ; otherwise, do nothing :)
end


;; sniff left and right, and go where the strongest smell is
to uphill-nest-scent  ;; turtle procedure
  let loc (item nest nest-locs)
  let x (first loc)
  let y (last loc)
  set heading 180 + atan (xcor - x) (ycor - y)
end

to wiggle  ;; turtle procedure
  rt random 40
  lt random 40
  if not can-move? 1 [ rt 180 ]
end

to move-around-rank-edge
  let patch_set (patch-set patch-right-and-ahead 45 1  patch-right-and-ahead 0 1  patch-right-and-ahead -45 1)   ; makes a patch-set of the three patches directly in front of the ant
  let patch_list sort-on [chemical] patch_set                    ;turns the patch-set into a list (currently only way I can find to do this is by sorting it)

  if length patch_list = 0 [rt 180
                            stop]                       ;if there are no patches in the list, turn around and face the other direction

   if length patch_list = 1                              ;if there is one patch in the list, choose it
    [let patch_i item 0 patch_list
     let ci ([chemical] of patch_i)
      if patch-right-and-ahead 45 1 = patch_i [rt 45]
      if patch-right-and-ahead -45 1 = patch_i [lt 45]]


  if length patch_list = 2                              ;if there are two items in the patch list, run the probability test on one, then the other
    [let patch_i item 1 patch_list
     let patch_j item 0 patch_list
     let ci ([chemical] of patch_i)
     let cj ([chemical] of patch_j)

      let rand2 (random 100) / 100
      ifelse rand2 < (1 - qprob)
      [if patch-right-and-ahead 45 1 = patch_i [rt 45]
        if patch-right-and-ahead -45 1 = patch_i [lt 45]]
      [if patch-right-and-ahead 45 1 = patch_j [rt 45]
        if patch-right-and-ahead -45 1 = patch_j [lt 45]]]


  if length patch_list = 3                              ;if there are three items in the patch list:
   [let patch_i item 2 patch_list
    let patch_j item 1 patch_list
    let patch_k item 0 patch_list

    let ci [chemical] of patch_i
    let cj [chemical] of patch_j
    let ck [chemical] of patch_k


    let rand1 (random 100) / 100
    ifelse rand1 < (1 - qprob)
      [if patch-right-and-ahead 45 1 = patch_i [rt 45 ]
       if patch-right-and-ahead -45 1 = patch_i [lt 45 ]] ;the ant chooses to go towards this patch
      [let rand2 (random 100) / 100
       ifelse rand2 < (1 - qprob)
         [if patch-right-and-ahead 45 1 = patch_j [rt 45]
          if patch-right-and-ahead -45 1 = patch_j [lt 45]] ;the ant chooses to go towards this patch
         [if patch-right-and-ahead 45 1 = patch_k [rt 45]
          if patch-right-and-ahead -45 1 = patch_k [lt 45]]]]
 end


;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Reporter procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; calculates euclidean distance between two points, couldn't find a built-in for this...
to-report dist [x1 y1 x2 y2]
  report sqrt ((x1 - x2) ^ 2 + (y1 - y2) ^ 2)
end

;; calculates the distance from a source to the closest nest
to-report dist-source-nest [source]
  let distances (list )
  (foreach nest-locs
    [[nloc] ->
     let nx first nloc
     let ny last nloc

     let sloc (item source source-locs)
     let sx first sloc
     let sy last sloc

     set distances fput (dist nx ny sx sy) distances
  ])
  report min distances
end

to-report dist-nest-nest [n1 n2]
  let loc1 (item n1 nest-locs)
  let x1 first loc1
  let y1 last loc1

  let loc2 (item n2 nest-locs)
  let x2 first loc2
  let y2 last loc2

  report dist x1 y1 x2 y2
end

to-report strength [s]
;  (ifelse
;    s = 1 [report (count turtles with [(status = "return-from-1" or status = "foraging-for-1")]) / (dist food-1-x food-1-y nest-1-x nest-1-y)]
;    s = 2 [report (count turtles with [(status = "return-from-2" or status = "foraging-for-2")]) / (dist food-2-x food-1-y nest-1-x nest-1-y)]
;    s = 3 [report (count turtles with [(status = "return-from-3" or status = "foraging-for-3")]) / (dist food-3-x food-3-y nest-1-x nest-1-y)]
;    s = 4 [report (count turtles with [(status = "return-from-4" or status = "foraging-for-4")]) / (dist food-4-x food-4-y nest-1-x nest-1-y)]
;    s = 5 [report (count turtles with [(status = "return-from-5" or status = "foraging-for-5")]) / (dist food-5-x food-5-y nest-1-x nest-1-y)]
;    )
end

to-report strength-list
;  report (list (strength 1) (strength 2) (strength 3) (strength 4) (strength 5))
end

;; returns the number of the food source with the strongest trial
to-report strongest-source
  let strengths strength-list
  let strongest (max strengths)
  report (((position strongest strengths) mod 5) + 1)
end

;; returns the number of the weakest food source that is above a threshold
to-report weakest-source
  let strengths strength-list
  let strongest (max strengths)
  let weakest (min strengths)

  while [weakest != strongest][
    let weak-index (position weakest strengths)
    ifelse weakest >= 2.5 [
      ; if the weakest is above the threshold, report its strength
      report weak-index + 1
    ] [
     ; if the weakest is not above the threshold, replace its value with that of the strongest and try again.
     ; This allows us to find the second weakest, third weakest, ...
     ; If none of the strengths are above the threshold, then we report 0
     set strengths replace-item weak-index strengths strongest
     set weakest (min strengths)
    ]
  ]
  report 0
end

;; returns the number of a random food source that is above a threshold
to-report random-source
  if max strength-list < 0.25 [report 0] ; no trail has a measurable amount of ants on it
  let rand-source ((random 5) + 1)
  ; keep choosing random sources until we choose one that has a measurable amount of ants on it
  while [strength rand-source < 0.25] [
    set rand-source ((random 5) + 1)
  ]
  report rand-source
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Experiment procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; set the production rate of food source s

to exclude
  set excluded-source-production (item excluded-source food-productions)
  set food-productions (replace-item excluded-source food-productions 0)
  set source-food (replace-item excluded-source source-food 0)
end

to include
  set food-productions (replace-item excluded-source food-productions excluded-source-production)
end
@#$#@#$#@
GRAPHICS-WINDOW
931
503
1214
787
-1
-1
4.51
1
30
1
1
1
0
0
0
1
-30
30
-30
30
1
1
1
hs
100.0

BUTTON
155
337
275
389
NIL
setup
NIL
1
T
OBSERVER
NIL
N
NIL
NIL
1

SLIDER
20
244
279
277
diffusion-rate
diffusion-rate
0
50
36.2
.2
1
NIL
HORIZONTAL

SLIDER
21
165
275
198
evaporation-rate
evaporation-rate
0
50
7.8
.05
1
NIL
HORIZONTAL

SLIDER
19
205
275
238
base-pheromone
base-pheromone
0
50
25.311
0.001
1
NIL
HORIZONTAL

SLIDER
303
67
475
100
pheromone-1
pheromone-1
0
5
1.0
.01
1
NIL
HORIZONTAL

BUTTON
284
337
407
389
NIL
go
T
1
T
OBSERVER
NIL
M
NIL
NIL
1

PLOT
915
799
1271
968
Ants on Trails
time
number of ants
0.0
100.0
0.0
20.0
true
true
"" ""
PENS
"Trail 1" 1.0 0 -10022847 true "" "plot count turtles with [status = 1 or status = 10]"
"pen-1" 1.0 0 -7500403 true "" "plot count turtles with [status = 2 or status = 20]"

SLIDER
515
146
687
179
qprob
qprob
0
1
0.05
0.01
1
NIL
HORIZONTAL

TEXTBOX
517
183
690
212
probability of an ant choosing a cell other than the highest chemical cell
11
0.0
1

SLIDER
515
68
687
101
prob
prob
0
1
0.98
0.01
1
NIL
HORIZONTAL

TEXTBOX
522
105
691
147
probability that an unloaded ant does not return to nest (yellow)
11
0.0
1

SLIDER
302
104
474
137
pheromone-2
pheromone-2
0
5
1.0
0.01
1
NIL
HORIZONTAL

SLIDER
302
144
474
177
pheromone-3
pheromone-3
0
5
1.0
0.01
1
NIL
HORIZONTAL

SLIDER
302
183
474
216
pheromone-4
pheromone-4
0
5
1.0
0.01
1
NIL
HORIZONTAL

SLIDER
303
222
475
255
pheromone-5
pheromone-5
0
5
1.0
0.01
1
NIL
HORIZONTAL

SLIDER
513
223
685
256
fprob
fprob
0
1
0.95
0.01
1
NIL
HORIZONTAL

TEXTBOX
513
268
706
324
probability of ant being oriented towards the food source it came from upon returning to the nest\n
11
0.0
1

TEXTBOX
355
35
408
53
Qualities
14
0.0
1

TEXTBOX
567
37
717
55
Probabilities
14
0.0
1

SLIDER
303
262
477
295
pheromone-nest
pheromone-nest
0
5
1.0
0.01
1
NIL
HORIZONTAL

PLOT
675
638
900
797
food in nests
time
food
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Nest 1" 1.0 0 -2674135 true "" "plot (item 0 nest-food)"
"Nest 2" 1.0 0 -8990512 true "" "plot (item 1 nest-food)"

TEXTBOX
875
41
1025
61
Positions
14
0.0
1

TEXTBOX
1127
39
1277
57
Production Rate
14
0.0
1

SLIDER
1325
150
1497
183
food-consumption
food-consumption
0
1
0.22
0.01
1
NIL
HORIZONTAL

TEXTBOX
1365
41
1515
59
Initial Food Stores
14
0.0
1

SLIDER
1324
235
1496
268
carrying-capacity
carrying-capacity
0
1000
30.0
1
1
NIL
HORIZONTAL

TEXTBOX
1290
278
1529
306
How much food each ant takes with it per trip.
11
0.0
1

TEXTBOX
1625
42
1775
60
Max Food Stores
14
0.0
1

PLOT
672
800
900
974
food in sources
time
food
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"food-1" 1.0 0 -16777216 true "" "plot (item 0 source-food)"
"food-2" 1.0 0 -7500403 true "" "plot (item 1 source-food)"
"food-3" 1.0 0 -2674135 true "" "plot (item 2 source-food)"
"food-4" 1.0 0 -955883 true "" "plot (item 3 source-food)"
"food-5" 1.0 0 -6459832 true "" "plot (item 4 source-food)"

SLIDER
1327
302
1499
335
storage-factor
storage-factor
0
5
1.0
0.1
1
NIL
HORIZONTAL

TEXTBOX
1332
195
1482
223
food consumption per ant per hs
11
0.0
1

TEXTBOX
1330
349
1480
405
Used in calculating how much food each colony can store, which is storage-factor * carrying-capacity * population.
11
0.0
1

TEXTBOX
1017
478
1123
496
Simulation Display
13
0.0
1

INPUTBOX
1390
565
1545
625
exclusion-start
400.0
1
0
Number

INPUTBOX
1390
636
1545
696
exclusion-stop
1000.0
1
0
Number

PLOT
0
421
669
698
Foraging Trail Strengths, Cross
Time (hs)
Strength (ants / m)
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"T0 -> N0" 1.0 0 -2674135 true "" "plot (count turtles with [(status = 1 or status = 10) and nest = 2]) / (dist-source-nest 0)"
"T1 -> N1" 1.0 0 -7500403 true "" "plot (count turtles with [status < 0 and nest != 2]) / (dist-nest-nest 0 1)"

PLOT
3
701
668
993
Internest Trail Strengths
Time (hs)
Strength (ants / m)
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Food from 2 -> 1" 1.0 0 -2674135 true "" "plot (count turtles with [(status < 0) and nest = 0]) / (dist-nest-nest 0 1)"
"Food from 1 -> 2" 1.0 0 -7500403 true "" "plot (count turtles with [(status < 0) and nest = 1]) / (dist-nest-nest 0 1)"

TEXTBOX
1438
427
1588
447
Exclusion
16
0.0
1

SWITCH
1410
458
1514
491
exclude?
exclude?
1
1
-1000

INPUTBOX
747
66
1069
126
source-loc
[[15 15] [15 -15] ] 
1
0
String (commands)

INPUTBOX
747
130
987
190
nest-loc
[[-15 5] ]
1
0
String (commands)

INPUTBOX
1295
69
1557
129
food-init
[10000 10000 10000 10000 10000]
1
0
String (commands)

INPUTBOX
1072
67
1295
127
food-production
[50 100 100 100 100]
1
0
String (commands)

MONITOR
673
422
918
467
NIL
source-food
17
1
11

INPUTBOX
1560
69
1799
129
food-max
[10000 10000 10000 10000 10000]
1
0
String (commands)

INPUTBOX
76
97
231
157
population
[1000]
1
0
String (commands)

TEXTBOX
219
10
369
52
I might remove qualities later since I think I'll want for everything to be the same?
11
0.0
1

MONITOR
674
472
741
517
NIL
nest-food
17
1
11

INPUTBOX
1392
497
1547
557
excluded-source
0.0
1
0
Number

@#$#@#$#@
## WHAT IS IT?

In this project, a colony of ants forages for food. Though each ant follows a set of simple rules, the colony as a whole acts in a sophisticated way.

## HOW IT WORKS

When an ant finds a piece of food, it carries the food back to the nest, dropping a chemical as it moves. When other ants "sniff" the chemical, they follow the chemical toward the food. As more ants carry food to the nest, they reinforce the chemical trail.

## HOW TO USE IT

Click the SETUP button to set up the ant nest (in violet, at center) and three piles of food. Click the GO button to start the simulation. The chemical is shown in a green-to-white gradient.

The EVAPORATION-RATE slider controls the evaporation rate of the chemical. The DIFFUSION-RATE slider controls the diffusion rate of the chemical.

If you want to change the number of ants, move the POPULATION slider before pressing SETUP.

## THINGS TO NOTICE

The ant colony generally exploits the food source in order, starting with the food closest to the nest, and finishing with the food most distant from the nest. It is more difficult for the ants to form a stable trail to the more distant food, since the chemical trail has more time to evaporate and diffuse before being reinforced.

Once the colony finishes collecting the closest food, the chemical trail to that food naturally disappears, freeing up ants to help collect the other food sources. The more distant food sources require a larger "critical number" of ants to form a stable trail.

The consumption of the food is shown in a plot.  The line colors in the plot match the colors of the food piles.

## EXTENDING THE MODEL

Try different placements for the food sources. What happens if two food sources are equidistant from the nest? When that happens in the real world, ant colonies typically exploit one source then the other (not at the same time).

In this project, the ants use a "trick" to find their way back to the nest: they follow the "nest scent." Real ants use a variety of different approaches to find their way back to the nest. Try to implement some alternative strategies.

The ants only respond to chemical levels between 0.05 and 2.  The lower limit is used so the ants aren't infinitely sensitive.  Try removing the upper limit.  What happens?  Why?

In the `uphill-chemical` procedure, the ant "follows the gradient" of the chemical. That is, it "sniffs" in three directions, then turns in the direction where the chemical is strongest. You might want to try variants of the `uphill-chemical` procedure, changing the number and placement of "ant sniffs."

## NETLOGO FEATURES

The built-in `diffuse` primitive lets us diffuse the chemical easily without complicated code.

The primitive `patch-right-and-ahead` is used to make the ants smell in different directions without actually turning.

## HOW TO CITE

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Wilensky, U. (1997).  NetLogo Ants model.  http://ccl.northwestern.edu/netlogo/models/Ants.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 1997 Uri Wilensky.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Uri Wilensky at uri@northwestern.edu.

This model was created as part of the project: CONNECTED MATHEMATICS: MAKING SENSE OF COMPLEX PHENOMENA THROUGH BUILDING OBJECT-BASED PARALLEL MODELS (OBPML).  The project gratefully acknowledges the support of the National Science Foundation (Applications of Advanced Technologies Program) -- grant numbers RED #9552950 and REC #9632612.

This model was developed at the MIT Media Lab using CM StarLogo.  See Resnick, M. (1994) "Turtles, Termites and Traffic Jams: Explorations in Massively Parallel Microworlds."  Cambridge, MA: MIT Press.  Adapted to StarLogoT, 1997, as part of the Connected Mathematics Project.

This model was converted to NetLogo as part of the projects: PARTICIPATORY SIMULATIONS: NETWORK-BASED DESIGN FOR SYSTEMS LEARNING IN CLASSROOMS and/or INTEGRATED SIMULATION AND MODELING ENVIRONMENT. The project gratefully acknowledges the support of the National Science Foundation (REPP & ROLE programs) -- grant numbers REC #9814682 and REC-0126227. Converted from StarLogoT to NetLogo, 1998.

<!-- 1997 1998 MIT -->
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.3.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="vary distance4" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="7660"/>
    <metric>count turtles with [status = "return-from-2" or status = "foraging-for-2"]</metric>
    <metric>count turtles with [status = "return-from-1" or status = "foraging-for-1"]</metric>
    <metric>count turtles with [status = "return-from-2"]</metric>
    <metric>count turtles with [status = "return-from-1"]</metric>
    <metric>[binStatus] of turtle 0</metric>
    <metric>[binStatus] of turtle 1</metric>
    <metric>[binStatus] of turtle 2</metric>
    <metric>[binStatus] of turtle 3</metric>
    <metric>[binStatus] of turtle 4</metric>
    <metric>[binStatus] of turtle 5</metric>
    <metric>[binStatus] of turtle 6</metric>
    <metric>[binStatus] of turtle 7</metric>
    <metric>[binStatus] of turtle 8</metric>
    <metric>[binStatus] of turtle 9</metric>
    <metric>[binStatus] of turtle 10</metric>
    <metric>[binStatus] of turtle 11</metric>
    <metric>[binStatus] of turtle 12</metric>
    <metric>[binStatus] of turtle 13</metric>
    <metric>[binStatus] of turtle 14</metric>
    <metric>[binStatus] of turtle 15</metric>
    <metric>[binStatus] of turtle 16</metric>
    <metric>[binStatus] of turtle 17</metric>
    <metric>[binStatus] of turtle 18</metric>
    <metric>[binStatus] of turtle 19</metric>
    <metric>[binStatus] of turtle 20</metric>
    <metric>[binStatus] of turtle 21</metric>
    <metric>[binStatus] of turtle 22</metric>
    <metric>[binStatus] of turtle 23</metric>
    <metric>[binStatus] of turtle 24</metric>
    <metric>[binStatus] of turtle 25</metric>
    <metric>[binStatus] of turtle 26</metric>
    <metric>[binStatus] of turtle 27</metric>
    <metric>[binStatus] of turtle 28</metric>
    <metric>[binStatus] of turtle 29</metric>
    <metric>[binStatus] of turtle 30</metric>
    <metric>[binStatus] of turtle 31</metric>
    <metric>[binStatus] of turtle 32</metric>
    <metric>[binStatus] of turtle 33</metric>
    <metric>[binStatus] of turtle 34</metric>
    <metric>[binStatus] of turtle 35</metric>
    <metric>[binStatus] of turtle 36</metric>
    <metric>[binStatus] of turtle 37</metric>
    <metric>[binStatus] of turtle 38</metric>
    <metric>[binStatus] of turtle 39</metric>
    <metric>[binStatus] of turtle 40</metric>
    <metric>[binStatus] of turtle 41</metric>
    <metric>[binStatus] of turtle 42</metric>
    <metric>[binStatus] of turtle 43</metric>
    <metric>[binStatus] of turtle 44</metric>
    <metric>[binStatus] of turtle 45</metric>
    <metric>[binStatus] of turtle 46</metric>
    <metric>[binStatus] of turtle 47</metric>
    <metric>[binStatus] of turtle 48</metric>
    <metric>[binStatus] of turtle 49</metric>
    <metric>[binStatus] of turtle 50</metric>
    <metric>[binStatus] of turtle 51</metric>
    <metric>[binStatus] of turtle 52</metric>
    <metric>[binStatus] of turtle 53</metric>
    <metric>[binStatus] of turtle 54</metric>
    <metric>[binStatus] of turtle 55</metric>
    <metric>[binStatus] of turtle 56</metric>
    <metric>[binStatus] of turtle 57</metric>
    <metric>[binStatus] of turtle 58</metric>
    <metric>[binStatus] of turtle 59</metric>
    <metric>[binStatus] of turtle 60</metric>
    <metric>[binStatus] of turtle 61</metric>
    <metric>[binStatus] of turtle 62</metric>
    <metric>[binStatus] of turtle 63</metric>
    <metric>[binStatus] of turtle 64</metric>
    <metric>[binStatus] of turtle 65</metric>
    <metric>[binStatus] of turtle 66</metric>
    <metric>[binStatus] of turtle 67</metric>
    <metric>[binStatus] of turtle 68</metric>
    <metric>[binStatus] of turtle 69</metric>
    <metric>[binStatus] of turtle 70</metric>
    <metric>[binStatus] of turtle 71</metric>
    <metric>[binStatus] of turtle 72</metric>
    <metric>[binStatus] of turtle 73</metric>
    <metric>[binStatus] of turtle 74</metric>
    <metric>[binStatus] of turtle 75</metric>
    <metric>[binStatus] of turtle 76</metric>
    <metric>[binStatus] of turtle 77</metric>
    <metric>[binStatus] of turtle 78</metric>
    <metric>[binStatus] of turtle 79</metric>
    <metric>[binStatus] of turtle 80</metric>
    <metric>[binStatus] of turtle 81</metric>
    <metric>[binStatus] of turtle 82</metric>
    <metric>[binStatus] of turtle 83</metric>
    <metric>[binStatus] of turtle 84</metric>
    <metric>[binStatus] of turtle 85</metric>
    <metric>[binStatus] of turtle 86</metric>
    <metric>[binStatus] of turtle 87</metric>
    <metric>[binStatus] of turtle 88</metric>
    <metric>[binStatus] of turtle 89</metric>
    <metric>[binStatus] of turtle 90</metric>
    <metric>[binStatus] of turtle 91</metric>
    <metric>[binStatus] of turtle 92</metric>
    <metric>[binStatus] of turtle 93</metric>
    <metric>[binStatus] of turtle 94</metric>
    <metric>[binStatus] of turtle 95</metric>
    <metric>[binStatus] of turtle 96</metric>
    <metric>[binStatus] of turtle 97</metric>
    <metric>[binStatus] of turtle 98</metric>
    <metric>[binStatus] of turtle 99</metric>
    <metric>[binStatus] of turtle 100</metric>
    <metric>[binStatus] of turtle 101</metric>
    <metric>[binStatus] of turtle 102</metric>
    <metric>[binStatus] of turtle 103</metric>
    <metric>[binStatus] of turtle 104</metric>
    <metric>[binStatus] of turtle 105</metric>
    <metric>[binStatus] of turtle 106</metric>
    <metric>[binStatus] of turtle 107</metric>
    <metric>[binStatus] of turtle 108</metric>
    <metric>[binStatus] of turtle 109</metric>
    <metric>[binStatus] of turtle 110</metric>
    <metric>[binStatus] of turtle 111</metric>
    <metric>[binStatus] of turtle 112</metric>
    <metric>[binStatus] of turtle 113</metric>
    <metric>[binStatus] of turtle 114</metric>
    <metric>[binStatus] of turtle 115</metric>
    <metric>[binStatus] of turtle 116</metric>
    <metric>[binStatus] of turtle 117</metric>
    <metric>[binStatus] of turtle 118</metric>
    <metric>[binStatus] of turtle 119</metric>
    <metric>[binStatus] of turtle 120</metric>
    <metric>[binStatus] of turtle 121</metric>
    <metric>[binStatus] of turtle 122</metric>
    <metric>[binStatus] of turtle 123</metric>
    <metric>[binStatus] of turtle 124</metric>
    <metric>[binStatus] of turtle 125</metric>
    <metric>[binStatus] of turtle 126</metric>
    <metric>[binStatus] of turtle 127</metric>
    <metric>[binStatus] of turtle 128</metric>
    <metric>[binStatus] of turtle 129</metric>
    <metric>[binStatus] of turtle 130</metric>
    <metric>[binStatus] of turtle 131</metric>
    <metric>[binStatus] of turtle 132</metric>
    <metric>[binStatus] of turtle 133</metric>
    <metric>[binStatus] of turtle 134</metric>
    <metric>[binStatus] of turtle 135</metric>
    <metric>[binStatus] of turtle 136</metric>
    <metric>[binStatus] of turtle 137</metric>
    <metric>[binStatus] of turtle 138</metric>
    <metric>[binStatus] of turtle 139</metric>
    <metric>[binStatus] of turtle 140</metric>
    <metric>[binStatus] of turtle 141</metric>
    <metric>[binStatus] of turtle 142</metric>
    <metric>[binStatus] of turtle 143</metric>
    <metric>[binStatus] of turtle 144</metric>
    <metric>[binStatus] of turtle 145</metric>
    <metric>[binStatus] of turtle 146</metric>
    <metric>[binStatus] of turtle 147</metric>
    <metric>[binStatus] of turtle 148</metric>
    <metric>[binStatus] of turtle 149</metric>
    <enumeratedValueSet variable="evaporation-rate">
      <value value="0.75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-logistic">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-rate">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="low-quality-pheromone">
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-ratio">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="qprob">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gparam">
      <value value="7.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-dist-1">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-dist-2">
      <value value="false"/>
    </enumeratedValueSet>
    <steppedValueSet variable="distance-1" first="0.17" step="0.04" last="0.93"/>
    <enumeratedValueSet variable="distance-2">
      <value value="0.5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="vary quality4" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="7660"/>
    <metric>count turtles with [status = "return-from-2" or status = "foraging-for-2"]</metric>
    <metric>count turtles with [status = "return-from-1" or status = "foraging-for-1"]</metric>
    <metric>count turtles with [status = "return-from-2"]</metric>
    <metric>count turtles with [status = "return-from-1"]</metric>
    <metric>[binStatus] of turtle 0</metric>
    <metric>[binStatus] of turtle 1</metric>
    <metric>[binStatus] of turtle 2</metric>
    <metric>[binStatus] of turtle 3</metric>
    <metric>[binStatus] of turtle 4</metric>
    <metric>[binStatus] of turtle 5</metric>
    <metric>[binStatus] of turtle 6</metric>
    <metric>[binStatus] of turtle 7</metric>
    <metric>[binStatus] of turtle 8</metric>
    <metric>[binStatus] of turtle 9</metric>
    <metric>[binStatus] of turtle 10</metric>
    <metric>[binStatus] of turtle 11</metric>
    <metric>[binStatus] of turtle 12</metric>
    <metric>[binStatus] of turtle 13</metric>
    <metric>[binStatus] of turtle 14</metric>
    <metric>[binStatus] of turtle 15</metric>
    <metric>[binStatus] of turtle 16</metric>
    <metric>[binStatus] of turtle 17</metric>
    <metric>[binStatus] of turtle 18</metric>
    <metric>[binStatus] of turtle 19</metric>
    <metric>[binStatus] of turtle 20</metric>
    <metric>[binStatus] of turtle 21</metric>
    <metric>[binStatus] of turtle 22</metric>
    <metric>[binStatus] of turtle 23</metric>
    <metric>[binStatus] of turtle 24</metric>
    <metric>[binStatus] of turtle 25</metric>
    <metric>[binStatus] of turtle 26</metric>
    <metric>[binStatus] of turtle 27</metric>
    <metric>[binStatus] of turtle 28</metric>
    <metric>[binStatus] of turtle 29</metric>
    <metric>[binStatus] of turtle 30</metric>
    <metric>[binStatus] of turtle 31</metric>
    <metric>[binStatus] of turtle 32</metric>
    <metric>[binStatus] of turtle 33</metric>
    <metric>[binStatus] of turtle 34</metric>
    <metric>[binStatus] of turtle 35</metric>
    <metric>[binStatus] of turtle 36</metric>
    <metric>[binStatus] of turtle 37</metric>
    <metric>[binStatus] of turtle 38</metric>
    <metric>[binStatus] of turtle 39</metric>
    <metric>[binStatus] of turtle 40</metric>
    <metric>[binStatus] of turtle 41</metric>
    <metric>[binStatus] of turtle 42</metric>
    <metric>[binStatus] of turtle 43</metric>
    <metric>[binStatus] of turtle 44</metric>
    <metric>[binStatus] of turtle 45</metric>
    <metric>[binStatus] of turtle 46</metric>
    <metric>[binStatus] of turtle 47</metric>
    <metric>[binStatus] of turtle 48</metric>
    <metric>[binStatus] of turtle 49</metric>
    <metric>[binStatus] of turtle 50</metric>
    <metric>[binStatus] of turtle 51</metric>
    <metric>[binStatus] of turtle 52</metric>
    <metric>[binStatus] of turtle 53</metric>
    <metric>[binStatus] of turtle 54</metric>
    <metric>[binStatus] of turtle 55</metric>
    <metric>[binStatus] of turtle 56</metric>
    <metric>[binStatus] of turtle 57</metric>
    <metric>[binStatus] of turtle 58</metric>
    <metric>[binStatus] of turtle 59</metric>
    <metric>[binStatus] of turtle 60</metric>
    <metric>[binStatus] of turtle 61</metric>
    <metric>[binStatus] of turtle 62</metric>
    <metric>[binStatus] of turtle 63</metric>
    <metric>[binStatus] of turtle 64</metric>
    <metric>[binStatus] of turtle 65</metric>
    <metric>[binStatus] of turtle 66</metric>
    <metric>[binStatus] of turtle 67</metric>
    <metric>[binStatus] of turtle 68</metric>
    <metric>[binStatus] of turtle 69</metric>
    <metric>[binStatus] of turtle 70</metric>
    <metric>[binStatus] of turtle 71</metric>
    <metric>[binStatus] of turtle 72</metric>
    <metric>[binStatus] of turtle 73</metric>
    <metric>[binStatus] of turtle 74</metric>
    <metric>[binStatus] of turtle 75</metric>
    <metric>[binStatus] of turtle 76</metric>
    <metric>[binStatus] of turtle 77</metric>
    <metric>[binStatus] of turtle 78</metric>
    <metric>[binStatus] of turtle 79</metric>
    <metric>[binStatus] of turtle 80</metric>
    <metric>[binStatus] of turtle 81</metric>
    <metric>[binStatus] of turtle 82</metric>
    <metric>[binStatus] of turtle 83</metric>
    <metric>[binStatus] of turtle 84</metric>
    <metric>[binStatus] of turtle 85</metric>
    <metric>[binStatus] of turtle 86</metric>
    <metric>[binStatus] of turtle 87</metric>
    <metric>[binStatus] of turtle 88</metric>
    <metric>[binStatus] of turtle 89</metric>
    <metric>[binStatus] of turtle 90</metric>
    <metric>[binStatus] of turtle 91</metric>
    <metric>[binStatus] of turtle 92</metric>
    <metric>[binStatus] of turtle 93</metric>
    <metric>[binStatus] of turtle 94</metric>
    <metric>[binStatus] of turtle 95</metric>
    <metric>[binStatus] of turtle 96</metric>
    <metric>[binStatus] of turtle 97</metric>
    <metric>[binStatus] of turtle 98</metric>
    <metric>[binStatus] of turtle 99</metric>
    <metric>[binStatus] of turtle 100</metric>
    <metric>[binStatus] of turtle 101</metric>
    <metric>[binStatus] of turtle 102</metric>
    <metric>[binStatus] of turtle 103</metric>
    <metric>[binStatus] of turtle 104</metric>
    <metric>[binStatus] of turtle 105</metric>
    <metric>[binStatus] of turtle 106</metric>
    <metric>[binStatus] of turtle 107</metric>
    <metric>[binStatus] of turtle 108</metric>
    <metric>[binStatus] of turtle 109</metric>
    <metric>[binStatus] of turtle 110</metric>
    <metric>[binStatus] of turtle 111</metric>
    <metric>[binStatus] of turtle 112</metric>
    <metric>[binStatus] of turtle 113</metric>
    <metric>[binStatus] of turtle 114</metric>
    <metric>[binStatus] of turtle 115</metric>
    <metric>[binStatus] of turtle 116</metric>
    <metric>[binStatus] of turtle 117</metric>
    <metric>[binStatus] of turtle 118</metric>
    <metric>[binStatus] of turtle 119</metric>
    <metric>[binStatus] of turtle 120</metric>
    <metric>[binStatus] of turtle 121</metric>
    <metric>[binStatus] of turtle 122</metric>
    <metric>[binStatus] of turtle 123</metric>
    <metric>[binStatus] of turtle 124</metric>
    <metric>[binStatus] of turtle 125</metric>
    <metric>[binStatus] of turtle 126</metric>
    <metric>[binStatus] of turtle 127</metric>
    <metric>[binStatus] of turtle 128</metric>
    <metric>[binStatus] of turtle 129</metric>
    <metric>[binStatus] of turtle 130</metric>
    <metric>[binStatus] of turtle 131</metric>
    <metric>[binStatus] of turtle 132</metric>
    <metric>[binStatus] of turtle 133</metric>
    <metric>[binStatus] of turtle 134</metric>
    <metric>[binStatus] of turtle 135</metric>
    <metric>[binStatus] of turtle 136</metric>
    <metric>[binStatus] of turtle 137</metric>
    <metric>[binStatus] of turtle 138</metric>
    <metric>[binStatus] of turtle 139</metric>
    <metric>[binStatus] of turtle 140</metric>
    <metric>[binStatus] of turtle 141</metric>
    <metric>[binStatus] of turtle 142</metric>
    <metric>[binStatus] of turtle 143</metric>
    <metric>[binStatus] of turtle 144</metric>
    <metric>[binStatus] of turtle 145</metric>
    <metric>[binStatus] of turtle 146</metric>
    <metric>[binStatus] of turtle 147</metric>
    <metric>[binStatus] of turtle 148</metric>
    <metric>[binStatus] of turtle 149</metric>
    <enumeratedValueSet variable="evaporation-rate">
      <value value="0.75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population">
      <value value="150"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-logistic">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-rate">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="qprob">
      <value value="0.2"/>
    </enumeratedValueSet>
    <steppedValueSet variable="low-quality-pheromone" first="3" step="1.5" last="31.5"/>
    <enumeratedValueSet variable="pheromone-ratio">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gparam">
      <value value="7.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-dist-1">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-dist-2">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-1">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-2">
      <value value="0.5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="test_val_1" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>[xcor] of turtles</metric>
    <metric>[ycor] of turtles</metric>
    <enumeratedValueSet variable="evaporation-rate">
      <value value="1.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population">
      <value value="1500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-logistic">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-rate">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="low-quality-pheromone">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-ratio">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="qprob">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gparam">
      <value value="7.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-dist-1">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-dist-2">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob">
      <value value="0.85"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Exp1" repetitions="10" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1500"/>
    <metric>count turtles with [status = "return-from-1" or status = "foraging-for-1"]</metric>
    <enumeratedValueSet variable="evaporation-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-2">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-dist-2">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gparam">
      <value value="7.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="low-quality-pheromone">
      <value value="0.01"/>
      <value value="0.1"/>
      <value value="1"/>
      <value value="2"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="qprob">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population">
      <value value="100"/>
      <value value="1000"/>
      <value value="5000"/>
      <value value="10000"/>
      <value value="20000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-ratio">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-logistic">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-1">
      <value value="0.1"/>
      <value value="0.25"/>
      <value value="0.5"/>
      <value value="0.75"/>
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-dist-1">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Exp2" repetitions="2" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1500"/>
    <metric>count turtles with [status = "return-from-1" or status = "foraging-for-1"]</metric>
    <enumeratedValueSet variable="evaporation-rate">
      <value value="1"/>
      <value value="5"/>
      <value value="10"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-rate">
      <value value="1"/>
      <value value="5"/>
      <value value="10"/>
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-2">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-dist-2">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gparam">
      <value value="7.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob">
      <value value="0.8"/>
      <value value="0.85"/>
      <value value="0.9"/>
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="low-quality-pheromone">
      <value value="1"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="qprob">
      <value value="0"/>
      <value value="0.05"/>
      <value value="0.1"/>
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population">
      <value value="1000"/>
      <value value="10000"/>
      <value value="20000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-ratio">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-logistic">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-1">
      <value value="0.1"/>
      <value value="0.5"/>
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-dist-1">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Exp_diffusion" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="150"/>
    <metric>[who] of turtles</metric>
    <metric>[pxcor] of turtles</metric>
    <metric>[pycor] of turtles</metric>
    <enumeratedValueSet variable="evaporation-rate">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-dist-2">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-2">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gparam">
      <value value="7.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="low-quality-pheromone">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="qprob">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population">
      <value value="20000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-ratio">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-logistic">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-rate">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-1">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="random-dist-1">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Config1" repetitions="25" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2500"/>
    <metric>count turtles with [status = "return-from-1" or status = "foraging-for-1"]</metric>
    <metric>count turtles with [status = "return-from-2" or status = "foraging-for-2"]</metric>
    <metric>count turtles with [status = "return-from-3" or status = "foraging-for-3"]</metric>
    <metric>count turtles with [status = "return-from-4" or status = "foraging-for-4"]</metric>
    <enumeratedValueSet variable="population">
      <value value="4000"/>
      <value value="20000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-1">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-2">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-3">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-4">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-5">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-1">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-2">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-3">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-4">
      <value value="1.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-5">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaporation-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-rate">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="base-pheromone">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="qprob">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fprob">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nest-location">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="angle-between-nests">
      <value value="90"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Config2" repetitions="25" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2500"/>
    <metric>count turtles with [status = "return-from-1" or status = "foraging-for-1"]</metric>
    <metric>count turtles with [status = "return-from-2" or status = "foraging-for-2"]</metric>
    <metric>count turtles with [status = "return-from-3" or status = "foraging-for-3"]</metric>
    <metric>count turtles with [status = "return-from-4" or status = "foraging-for-4"]</metric>
    <enumeratedValueSet variable="population">
      <value value="4000"/>
      <value value="20000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-1">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-4">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-2">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-3">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-5">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-1">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-4">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-2">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-3">
      <value value="1.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-5">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaporation-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-rate">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="base-pheromone">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="qprob">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fprob">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nest-location">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="angle-between-nests">
      <value value="90"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Config3" repetitions="25" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2500"/>
    <metric>count turtles with [status = "return-from-1" or status = "foraging-for-1"]</metric>
    <metric>count turtles with [status = "return-from-2" or status = "foraging-for-2"]</metric>
    <metric>count turtles with [status = "return-from-3" or status = "foraging-for-3"]</metric>
    <metric>count turtles with [status = "return-from-4" or status = "foraging-for-4"]</metric>
    <enumeratedValueSet variable="population">
      <value value="4000"/>
      <value value="20000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-1">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-3">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-4">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-2">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-5">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-1">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-3">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-4">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-2">
      <value value="1.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-5">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaporation-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-rate">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="base-pheromone">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="qprob">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fprob">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nest-location">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="angle-between-nests">
      <value value="90"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ControlDistance" repetitions="25" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="3000"/>
    <metric>count turtles with [status = "return-from-1" or status = "foraging-for-1"]</metric>
    <metric>count turtles with [status = "return-from-2" or status = "foraging-for-2"]</metric>
    <metric>count turtles with [status = "return-from-3" or status = "foraging-for-3"]</metric>
    <metric>count turtles with [status = "return-from-4" or status = "foraging-for-4"]</metric>
    <enumeratedValueSet variable="population">
      <value value="4000"/>
      <value value="20000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-1">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-2">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-3">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-4">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-5">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-1">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-2">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-3">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-4">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-5">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaporation-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-rate">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="base-pheromone">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="qprob">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fprob">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nest-location">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="angle-between-nests">
      <value value="90"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Config2_Baseline" repetitions="25" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2500"/>
    <metric>count turtles with [status = "return-from-1" or status = "foraging-for-1"]</metric>
    <metric>count turtles with [status = "return-from-2" or status = "foraging-for-2"]</metric>
    <metric>count turtles with [status = "return-from-3" or status = "foraging-for-3"]</metric>
    <metric>count turtles with [status = "return-from-4" or status = "foraging-for-4"]</metric>
    <enumeratedValueSet variable="population">
      <value value="4000"/>
      <value value="20000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-1">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-4">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-2">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-3">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-5">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-1">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-4">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-2">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-3">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-5">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaporation-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-rate">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="base-pheromone">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="qprob">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fprob">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nest-location">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="angle-between-nests">
      <value value="90"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Config3_Baseline" repetitions="25" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2500"/>
    <metric>count turtles with [status = "return-from-1" or status = "foraging-for-1"]</metric>
    <metric>count turtles with [status = "return-from-2" or status = "foraging-for-2"]</metric>
    <metric>count turtles with [status = "return-from-3" or status = "foraging-for-3"]</metric>
    <metric>count turtles with [status = "return-from-4" or status = "foraging-for-4"]</metric>
    <enumeratedValueSet variable="population">
      <value value="4000"/>
      <value value="20000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-1">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-3">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-4">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-2">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-5">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-1">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-3">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-4">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-2">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-5">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaporation-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-rate">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="base-pheromone">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="qprob">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fprob">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nest-location">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="angle-between-nests">
      <value value="90"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ControlD0.50Q2.00" repetitions="25" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles with [status = "return-from-1" or status = "foraging-for-1"]</metric>
    <metric>count turtles with [status = "return-from-2" or status = "foraging-for-2"]</metric>
    <metric>count turtles with [status = "return-from-3" or status = "foraging-for-3"]</metric>
    <metric>count turtles with [status = "return-from-4" or status = "foraging-for-4"]</metric>
    <enumeratedValueSet variable="population">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-1">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-2">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-3">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-4">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-5">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-1">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-2">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-3">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-4">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-5">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaporation-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-rate">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="base-pheromone">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="qprob">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fprob">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nest-location">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="angle-between-nests">
      <value value="90"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ControlD0.40Q1.20" repetitions="25" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles with [status = "return-from-1" or status = "foraging-for-1"]</metric>
    <metric>count turtles with [status = "return-from-2" or status = "foraging-for-2"]</metric>
    <metric>count turtles with [status = "return-from-3" or status = "foraging-for-3"]</metric>
    <metric>count turtles with [status = "return-from-4" or status = "foraging-for-4"]</metric>
    <enumeratedValueSet variable="population">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-1">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-2">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-3">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-4">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-5">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-1">
      <value value="1.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-2">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-3">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-4">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-5">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaporation-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-rate">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="base-pheromone">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="qprob">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fprob">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nest-location">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="angle-between-nests">
      <value value="90"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ControlD0.35Q0.70" repetitions="25" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles with [status = "return-from-1" or status = "foraging-for-1"]</metric>
    <metric>count turtles with [status = "return-from-2" or status = "foraging-for-2"]</metric>
    <metric>count turtles with [status = "return-from-3" or status = "foraging-for-3"]</metric>
    <metric>count turtles with [status = "return-from-4" or status = "foraging-for-4"]</metric>
    <enumeratedValueSet variable="population">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-1">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-2">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-3">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-4">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-5">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-1">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-2">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-3">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-4">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-5">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaporation-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-rate">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="base-pheromone">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="qprob">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fprob">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nest-location">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="angle-between-nests">
      <value value="90"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ControlD0.25Q0.25" repetitions="25" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>count turtles with [status = "return-from-1" or status = "foraging-for-1"]</metric>
    <metric>count turtles with [status = "return-from-2" or status = "foraging-for-2"]</metric>
    <metric>count turtles with [status = "return-from-3" or status = "foraging-for-3"]</metric>
    <metric>count turtles with [status = "return-from-4" or status = "foraging-for-4"]</metric>
    <enumeratedValueSet variable="population">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-1">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-2">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-3">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-4">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-5">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-1">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-2">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-3">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-4">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-5">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaporation-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-rate">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="base-pheromone">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="qprob">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fprob">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nest-location">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="angle-between-nests">
      <value value="90"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ControlDistance2" repetitions="25" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="3000"/>
    <metric>count turtles with [status = "return-from-1" or status = "foraging-for-1"]</metric>
    <metric>count turtles with [status = "return-from-2" or status = "foraging-for-2"]</metric>
    <metric>count turtles with [status = "return-from-3" or status = "foraging-for-3"]</metric>
    <metric>count turtles with [status = "return-from-4" or status = "foraging-for-4"]</metric>
    <enumeratedValueSet variable="population">
      <value value="4000"/>
      <value value="20000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-1">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-2">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-3">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-4">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-5">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-1">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-4">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-3">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-2">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-5">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaporation-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-rate">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="base-pheromone">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="qprob">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fprob">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nest-location">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="angle-between-nests">
      <value value="90"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ControlDistance3" repetitions="25" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="3000"/>
    <metric>count turtles with [status = "return-from-1" or status = "foraging-for-1"]</metric>
    <metric>count turtles with [status = "return-from-2" or status = "foraging-for-2"]</metric>
    <metric>count turtles with [status = "return-from-3" or status = "foraging-for-3"]</metric>
    <metric>count turtles with [status = "return-from-4" or status = "foraging-for-4"]</metric>
    <enumeratedValueSet variable="population">
      <value value="4000"/>
      <value value="20000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-1">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-2">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-3">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-4">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-5">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-1">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-2">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-4">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-3">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-5">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaporation-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-rate">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="base-pheromone">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="qprob">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fprob">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nest-location">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="angle-between-nests">
      <value value="90"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Config1B" repetitions="25" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2500"/>
    <metric>count turtles with [status = "return-from-1" or status = "foraging-for-1"]</metric>
    <metric>count turtles with [status = "return-from-2" or status = "foraging-for-2"]</metric>
    <metric>count turtles with [status = "return-from-3" or status = "foraging-for-3"]</metric>
    <metric>count turtles with [status = "return-from-4" or status = "foraging-for-4"]</metric>
    <enumeratedValueSet variable="population">
      <value value="4000"/>
      <value value="20000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-1">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-2">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-3">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-4">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-5">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-1">
      <value value="1.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-2">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-3">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-4">
      <value value="1.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-5">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaporation-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-rate">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="base-pheromone">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="qprob">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fprob">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nest-location">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="angle-between-nests">
      <value value="90"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Config2B" repetitions="25" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2500"/>
    <metric>count turtles with [status = "return-from-1" or status = "foraging-for-1"]</metric>
    <metric>count turtles with [status = "return-from-2" or status = "foraging-for-2"]</metric>
    <metric>count turtles with [status = "return-from-3" or status = "foraging-for-3"]</metric>
    <metric>count turtles with [status = "return-from-4" or status = "foraging-for-4"]</metric>
    <enumeratedValueSet variable="population">
      <value value="4000"/>
      <value value="20000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-1">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-4">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-2">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-3">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-5">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-1">
      <value value="1.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-4">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-2">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-3">
      <value value="1.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-5">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaporation-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-rate">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="base-pheromone">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="qprob">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fprob">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nest-location">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="angle-between-nests">
      <value value="90"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Config3B" repetitions="25" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2500"/>
    <metric>count turtles with [status = "return-from-1" or status = "foraging-for-1"]</metric>
    <metric>count turtles with [status = "return-from-2" or status = "foraging-for-2"]</metric>
    <metric>count turtles with [status = "return-from-3" or status = "foraging-for-3"]</metric>
    <metric>count turtles with [status = "return-from-4" or status = "foraging-for-4"]</metric>
    <enumeratedValueSet variable="population">
      <value value="4000"/>
      <value value="20000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-1">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-3">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-4">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-2">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-5">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-1">
      <value value="1.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-3">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-4">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-2">
      <value value="1.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-5">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaporation-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-rate">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="base-pheromone">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="qprob">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fprob">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nest-location">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="angle-between-nests">
      <value value="90"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Config1Pheromone" repetitions="25" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2500"/>
    <metric>count turtles with [status = "return-from-1" or status = "foraging-for-1"]</metric>
    <metric>count turtles with [status = "return-from-2" or status = "foraging-for-2"]</metric>
    <metric>count turtles with [status = "return-from-3" or status = "foraging-for-3"]</metric>
    <metric>count turtles with [status = "return-from-4" or status = "foraging-for-4"]</metric>
    <enumeratedValueSet variable="population">
      <value value="4000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-1">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-2">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-3">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-4">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-5">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-1">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-2">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-3">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-4">
      <value value="1.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-5">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaporation-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-rate">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="base-pheromone">
      <value value="50"/>
      <value value="250"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="qprob">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fprob">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nest-location">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="angle-between-nests">
      <value value="90"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Config1Baseline" repetitions="25" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2500"/>
    <metric>count turtles with [status = "return-from-1" or status = "foraging-for-1"]</metric>
    <metric>count turtles with [status = "return-from-2" or status = "foraging-for-2"]</metric>
    <metric>count turtles with [status = "return-from-3" or status = "foraging-for-3"]</metric>
    <metric>count turtles with [status = "return-from-4" or status = "foraging-for-4"]</metric>
    <enumeratedValueSet variable="population">
      <value value="4000"/>
      <value value="20000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-1">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-2">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-3">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-4">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-5">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-1">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-2">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-3">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-4">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-5">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaporation-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-rate">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="base-pheromone">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="qprob">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fprob">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nest-location">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="angle-between-nests">
      <value value="90"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ControlQuality1A" repetitions="25" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2500"/>
    <metric>count turtles with [status = "return-from-1" or status = "foraging-for-1"]</metric>
    <metric>count turtles with [status = "return-from-2" or status = "foraging-for-2"]</metric>
    <metric>count turtles with [status = "return-from-3" or status = "foraging-for-3"]</metric>
    <metric>count turtles with [status = "return-from-4" or status = "foraging-for-4"]</metric>
    <enumeratedValueSet variable="population">
      <value value="4000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-1">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-2">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-3">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-4">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-5">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-1">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-2">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-3">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-4">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-5">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaporation-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-rate">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="base-pheromone">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob">
      <value value="0.9"/>
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="qprob">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fprob">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nest-location">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="angle-between-nests">
      <value value="90"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ControlDistanceA" repetitions="25" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2500"/>
    <metric>count turtles with [status = "return-from-1" or status = "foraging-for-1"]</metric>
    <metric>count turtles with [status = "return-from-2" or status = "foraging-for-2"]</metric>
    <metric>count turtles with [status = "return-from-3" or status = "foraging-for-3"]</metric>
    <metric>count turtles with [status = "return-from-4" or status = "foraging-for-4"]</metric>
    <enumeratedValueSet variable="population">
      <value value="4000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-1">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-2">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-3">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-4">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-5">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-1">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-2">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-3">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-4">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-5">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaporation-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-rate">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="base-pheromone">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob">
      <value value="0.9"/>
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="qprob">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fprob">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nest-location">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="angle-between-nests">
      <value value="90"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Config1A" repetitions="25" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2500"/>
    <metric>count turtles with [status = "return-from-1" or status = "foraging-for-1"]</metric>
    <metric>count turtles with [status = "return-from-2" or status = "foraging-for-2"]</metric>
    <metric>count turtles with [status = "return-from-3" or status = "foraging-for-3"]</metric>
    <metric>count turtles with [status = "return-from-4" or status = "foraging-for-4"]</metric>
    <enumeratedValueSet variable="population">
      <value value="4000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-1">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-2">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-3">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-4">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-5">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-1">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-2">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-3">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-4">
      <value value="1.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pheromone-5">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="evaporation-rate">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diffusion-rate">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="base-pheromone">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob">
      <value value="0.9"/>
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="qprob">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fprob">
      <value value="0.95"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nest-location">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="angle-between-nests">
      <value value="90"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
