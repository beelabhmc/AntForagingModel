extensions [profiler]

patches-own [
  chemical1            ;; amount of chemical on this patch
  chemical2            ;; amount of chemical from the second patch
  chemical3            ;; amount of chemical on this patch
  chemical4            ;; amount of chemical from the second patch
  chemical5            ;; amount of chemical on this patch
  chemical             ;; sum of all the chemical in the patch
  nest?                ;; true on nest patches, false elsewhere
  nest-scent           ;; number that is higher closer to the nest
  food-source-number   ;; number (1 or 2) to identify the food sources
]

turtles-own [
  status               ;; variable telling the turtle what it is currently doing (string form, differentiates between trails)
                       ;;                   statuses: "at nest", "return-from-1", "return-from-2", "return-from-3", "return-from-4", "return-from-5", "foraging-for-1", "foraging-for-2", "foraging-for-3", "foraging-for-4", "foraging-for-5", "foraging"
                       ;; corresponds with binStatus:    0    ,       10        ,       20       ,        30      ,        40      ,     50         ,        1        ,         2       ,         3,      ,       4,        ,        5,       ,    99
                       ;; corresponds with binStatus:    20    ,       1        ,       11       ,        4        ,        14       ,     0
  binStatus            ;; variable telling the turtle what it is currently doing (integer form)
                       ;;      binStatus key is listed above with status variable
  prevfood             ;; variable holding the information for the quality of the food the turtle is carrying (0, 1, or 10)
 ; prob                 ;; probability of an ant leaving the nest at any given time scale
]

;;;;;;;;;;;;;;;;;;;;;;;;
;;; Setup procedures ;;;
;;;;;;;;;;;;;;;;;;;;;;;;

globals
 [source-1
  source-2
  source-3
  source-4
  ]


to setup
  clear-all
  set-default-shape turtles "bug"
  create-turtles population
  [ set size 0.28         ;; should be 0.28 when to scale
    set status "at nest"
    set prevfood 0
    set binStatus 0
    ;set prob 0.9
    set color red
    setxy 0 nest-location

    right random 360


  ]
  ;; red = not carrying food
  setup-patches
  reset-ticks
  set source-1 []
  set source-2 []
  set source-3 []
  set source-4 []
end

to setup-patches
  ask patches
  [ setup-nest
    setup-food
    recolor-patch ]
end

to setup-nest  ;; patch procedure
  ;; set nest? variable to true inside the nest, false elsewhere
  set nest? (distancexy 0 nest-location) < 4
  ;; spread a nest-scent over the whole world -- stronger near the nest
  set nest-scent 200 - distancexy 0 nest-location
end


to setup-food  ;; patch procedure
  ;; Max number of food sources is 5
  ;; Lays out food sources left to right, each the same angle apart
  (foreach [1 2 3 4 5] (list distance-1 distance-2 distance-3 distance-4 distance-5)
    [[a b] ->
      let angle angle-between-nests * (a - 1)
      let food-x sin(angle) * b * max-pxcor
      let food-y cos(angle) * b * max-pycor
      if (distancexy food-x food-y < 2) [set food-source-number a]
    ])
end

to recolor-patch  ;; patch procedure
  ;; give color to nest and food sources
  ifelse nest?
  [ set pcolor violet ]
  [if food-source-number > 0 [set pcolor 66]]
  ;; scale color to show chemical concentration
  if (nest? = false and food-source-number = 0)[
    set pcolor scale-color magenta (chemical1 + chemical2 + chemical3 + chemical4 + chemical5) 0.05 300
  ]
end

;;;;;;;;;;;;;;;;;;;;;
;;; Go procedures ;;;
;;;;;;;;;;;;;;;;;;;;;

to-report report-source-1
 report source-1
end

to go  ;; forever button
  ask turtles
 [
    ifelse color = red
    [ ifelse nest? = true
      [ set binStatus 0
        look-for-food
      ][
        look-for-food
      ]
    ]
    [ ifelse color = blue
      [
        return-to-nest ] ;; carrying food? take it back to nest
      [
        return-to-nest-no-food
      ]
    ]
    wiggle
    fd 1 ]
  diffuse chemical1 (diffusion-rate / 100)
  diffuse chemical2 (diffusion-rate / 100)
  diffuse chemical3 (diffusion-rate / 100)
  diffuse chemical4 (diffusion-rate / 100)
  diffuse chemical5 (diffusion-rate / 100)

  ask patches
  [ set chemical1 chemical1 * (100 - evaporation-rate) / 100  ;; slowly evaporate chemical
    set chemical2 chemical2 * (100 - evaporation-rate) / 100
    set chemical3 chemical3 * (100 - evaporation-rate) / 100
    set chemical4 chemical4 * (100 - evaporation-rate) / 100
    set chemical5 chemical5 * (100 - evaporation-rate) / 100
    set chemical chemical1 + chemical2 + chemical3 + chemical4 + chemical5
    recolor-patch ]
  tick

  ;counts
  set source-1 lput count turtles with [status = "return-from-1" or status = "foraging-for-1"] source-1
  set source-2 lput count turtles with [status = "return-from-2" or status = "foraging-for-2"] source-2
  set source-3 lput count turtles with [status = "return-from-3" or status = "foraging-for-3"] source-3
  set source-4 lput count turtles with [status = "return-from-4" or status = "foraging-for-4"] source-4

end

to return-to-nest  ;; turtle procedure
  ifelse nest?
    [ ;; drop food and head out again
      set color red

      ;orient the ant in the direction of its previous food source
      ifelse (random-float 1 < fprob)[
        set heading angle-between-nests * (prevfood - 1)

      ][
       right random 360
      ]

      set prevfood 0         ;this resets the quality of the food the turtle is carrying, since it has deposited its food
      set binStatus 0       ;this resets the binary status of the turtles so that they are foraging w/o a trail
      set status "at nest"   ;this resets the status of the turtle for it to go out again and forage (this will probably want to be changed later to have memory of the previous food source)

      setxy 0 nest-location
    ]
    ;; two sliders for pheromone-ratio and low-quality-pheromone
    ;; pheromone-ratio represents how many times larger the high-quality pheromone is than the low-quality pheromone
    ;; low-quality-pheromone tells us how much pheromone the ants will leave after visiting the low-quality food source
    [if prevfood = 1 [set chemical1 chemical1 + base-pheromone * pheromone-1]    ; this drops chemical proportionately with the quality of the food that the turtle previously picked up (now logged in prevfood)
     if prevfood = 2 [set chemical2 chemical2 + base-pheromone * pheromone-2]
     if prevfood = 3 [set chemical3 chemical3 + base-pheromone * pheromone-3]
     if prevfood = 4 [set chemical4 chemical4 + base-pheromone * pheromone-4]
     if prevfood = 5 [set chemical5 chemical5 + base-pheromone * pheromone-5]
      uphill-nest-scent]
end

to return-to-nest-no-food  ;; turtle procedure
  ifelse nest?
  [ ;; head out again
     set color red
     set binStatus 0
     set status "at nest"   ;this resets the status of the turtle for it to go out again and forage (this will probably want to be changed later to have memory of the previous food source)
     setxy 0 nest-location
     right random 360
  ]
   [uphill-nest-scent]
    end



to look-for-food  ;; turtle procedure
  if food-source-number = 1
    [set color blue                             ; change the color of the turtle
     set status "return-from-1"               ; set status to be returning from food-source-number 1
     set binStatus 10                          ; sets binary status to full of food, returning to nest
     set prevfood 1                           ; set provfood status to be 1
     rt 180                                   ; turn around
     stop]
  if food-source-number = 2
    [set color blue                            ; change the color of the turtle to reflect a different food source
     set status "return-from-2"               ; change the status to be returning from the second food source
     set binStatus 20                         ; sets binary status to full of food, returning to nest
     set prevfood 2                           ; set prevfood status to be 2
     rt 180                                          ; turn around
     stop]
   if food-source-number = 3
    [set color blue                            ; change the color of the turtle to reflect a different food source
     set status "return-from-3"               ; change the status to be returning from the second food source
     set binStatus 30                         ; sets binary status to full of food, returning to nest
     set prevfood 3                           ; set prevfood status to be 2
     rt 180                                          ; turn around
     stop]
   if food-source-number = 4
    [set color blue                            ; change the color of the turtle to reflect a different food source
     set status "return-from-4"               ; change the status to be returning from the second food source
     set binStatus 40                         ; sets binary status to full of food, returning to nest
     set prevfood 4                           ; set prevfood status to be 2
     rt 180                                          ; turn around
     stop]
   if food-source-number = 5
    [set color blue                            ; change the color of the turtle to reflect a different food source
     set status "return-from-5"               ; change the status to be returning from the second food source
     set binStatus 50                         ; sets binary status to full of food, returning to nest
     set prevfood 5                           ; set prevfood status to be 2
     rt 180                                          ; turn around
     stop]


    ifelse (chemical >= 0.05)
        [let max-chem max (list chemical1 chemical2 chemical3 chemical4 chemical5)
          (ifelse
            max-chem = chemical1 [
              set status "foraging-for-1"
              set binStatus 1
            ]
            max-chem = chemical2 [
              set status "foraging-for-2"
              set binStatus 2
            ]
            max-chem = chemical3 [
              set status "foraging-for-3"
              set binStatus 3
            ]
            max-chem = chemical4 [
              set status "foraging-for-4"
              set binStatus 4
            ]
            max-chem = chemical5 [
              set status "foraging-for-5"
              set binStatus 5
            ]
          )
          move-around-rank-edge]
  [
    ifelse (random-float 1 < prob)[
      ifelse nest? = true
         [set status "at nest"
           set binStatus 20]
         [
        set status "foraging"
        set binStatus 99]]
 [
    set color yellow
    set status "foraging"
    set binStatus 99
    stop
  ]]
end


;; sniff left and right, and go where the strongest smell is
to uphill-nest-scent  ;; turtle procedure
  let scent-ahead nest-scent-at-angle   0
  let scent-right nest-scent-at-angle  45
  let scent-left  nest-scent-at-angle -45
  if (scent-right > scent-ahead) or (scent-left > scent-ahead)
  [ ifelse scent-right > scent-left
    [ rt 45 ]
    [ lt 45 ] ]
end

to wiggle  ;; turtle procedure
  rt random 40
  lt random 40
  if not can-move? 1 [ rt 180 ]
end

to-report nest-scent-at-angle [angle]
  let p patch-right-and-ahead angle 1
  if p = nobody [ report 0 ]
  report [nest-scent] of p
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


to profile
  setup
  profiler:reset
  profiler:start
  repeat 20 [go]
  profiler:stop
  let _fname "report.txt"
  carefully [file-delete _fname] []
  file-open _fname
  file-print profiler:report
  file-close
end

; Copyright 1997 Uri Wilensky.
; See Info tab for full copyright and license.
@#$#@#$#@
GRAPHICS-WINDOW
1181
10
1894
724
-1
-1
5.0
1
10
1
1
1
0
0
0
1
-70
70
-70
70
1
1
1
ticks
100.0

BUTTON
19
22
139
74
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
75
273
108
population
population
0
20000
20000.0
10
1
NIL
HORIZONTAL

SLIDER
20
114
274
147
diffusion-rate
diffusion-rate
0
50
15.0
.2
1
NIL
HORIZONTAL

SLIDER
19
151
273
184
evaporation-rate
evaporation-rate
0
50
10.0
.05
1
NIL
HORIZONTAL

SLIDER
19
192
275
225
base-pheromone
base-pheromone
0
50
50.0
0.001
1
NIL
HORIZONTAL

SLIDER
482
28
654
61
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
148
22
271
74
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
0
354
626
612
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
"Trail 1" 1.0 0 -10022847 true "" "plot count turtles with [status = \"return-from-1\" or status = \"foraging-for-1\"]"
"Trail 2" 1.0 0 -8330359 true "" "plot count turtles with [status = \"return-from-2\" or status = \"foraging-for-2\"]"
"Trail 3" 1.0 0 -2674135 true "" "plot count turtles with [status = \"return-from-3\" or status = \"foraging-for-3\"]"
"Trail 4" 1.0 0 -7500403 true "" "plot count turtles with [status = \"return-from-4\" or status = \"foraging-for-4\"]"
"Trail 5" 1.0 0 -955883 true "" "plot count turtles with [status = \"return-from-5\" or status = \"foraging-for-5\"]"

SLIDER
284
27
457
60
distance-1
distance-1
0
1
0.5
0.01
1
NIL
HORIZONTAL

SLIDER
286
74
459
107
distance-2
distance-2
0
1
0.4
0.01
1
NIL
HORIZONTAL

SLIDER
992
132
1164
165
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
99
278
282
348
pheromone-ratio represents how many times more pheromone ants produce for the high quality food source
11
0.0
1

TEXTBOX
994
169
1167
198
probability of an ant choosing a cell other than the highest chemical cell
11
0.0
1

SLIDER
991
18
1163
51
prob
prob
0
1
0.9
0.01
1
NIL
HORIZONTAL

TEXTBOX
998
55
1167
97
probability that an unloaded ant does not returns to nest (yellow)
11
0.0
1

SLIDER
277
278
449
311
nest-location
nest-location
-70
0
0.0
1
1
NIL
HORIZONTAL

SLIDER
286
120
458
153
distance-3
distance-3
0
1
0.35
0.01
1
NIL
HORIZONTAL

SLIDER
288
163
460
196
distance-4
distance-4
0
1
0.25
0.01
1
NIL
HORIZONTAL

SLIDER
288
212
460
245
distance-5
distance-5
0
1
1.0
0.01
1
NIL
HORIZONTAL

SLIDER
478
77
650
110
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
477
119
649
152
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
476
165
648
198
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
477
213
649
246
pheromone-5
pheromone-5
0
5
0.0
0.01
1
NIL
HORIZONTAL

SLIDER
1001
244
1173
277
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
991
289
1184
345
probability of ant being oriented towards the food source it came from upon returning to the nest\n
11
0.0
1

SLIDER
995
348
1167
381
angle-between-nests
angle-between-nests
0
360
90.0
1
1
NIL
HORIZONTAL

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
  <experiment name="Config1_Baseline" repetitions="25" runMetricsEveryStep="true">
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
