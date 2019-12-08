breed [mosquitoes mosquito]
breed [humans human]

;; global shared variables
globals [
  hospital-patches ;; patch where we show the "CROWDED" label
  world-patches ;; path that is the free roaming world
  humans-chance-reproduce ;; the probability of a human generating an offspring each tick
  mosquitoes-chance-reproduce ;; the probability of a mosquitoes generating offspring each tick
  mosquitoes-max-capacity ;; max num mosquites
  humans-max-capacity ;; max num humans
  previous-infections ;; previous malaria number
  current-infections ;; current number of malaria infections
  drug-efficacy ;; should be between 0 and 90%
  count-human-natural-deaths
  count-human-malaria-deaths
]

;; for humans and mosquitoes
turtles-own[
  age ;; how many days old the human turtle is
  sex ;; male or female
  lifespan ;; Length of life in ticks
  infected? ;; has malaria or not
  pregnant? ;; agent is pregnant, only females can be pregnant though.
  pregnancy-time ;; time being pregnant
]

;; human agents only
humans-own[
  infected-time ;; period that the human has been infected for
  time-to-symptoms ;; period of time before human recognises symptoms.
  thinks-infected? ;; does the human know that they are infected?
  antimalarial-drug-count
  ;; TODO: immune-time? shoud we have an immune feature, where people cannot get malaria
]

;; mosquitoes agents only
mosquitoes-own[
  bloodfeed-counter ;; days until next feed, only females when pregnant.
  bloodfed? ;; has the mosquito blood fed
]

;; initalize the interface and create enviroment
to setup
  clear-all
  set drug-efficacy 90 ;; TODO: maybe change later.
  setup-global-vars
  create-world  ;;create humans and mosquitoes
  create-agents
  update-display
  reset-ticks
end

to step
  go
end

to setup-global-vars
  set mosquitoes-max-capacity 500
  set humans-max-capacity 300
end

;start simulation
to go
  ask turtles[
    get-older ; inc turtle age and check if should die
    ;inc-infected-time ;; if infected inc infected time
    die-naturally
  ]

  set-drug-generation-counters

  get-drugs
  consume-drugs
  move
  recover-or-die

  reproduce
  birth

  bloodfeed
  update-infected-length
  check-infected
  update-display
  tick
end

;; create the world enviroment, world and hospitals
to create-world
  ;; create the 'world'
  set world-patches patches with [pycor <= 0 or (pxcor <=  0 and pycor >= 0)]
  ask world-patches [ set pcolor grey ]

  ;; create the 'hospital'
  set hospital-patches patches with [pxcor > 0 and pycor > 0]
  ask hospital-patches [ set pcolor blue ]

  set humans-chance-reproduce 1;10

  set mosquitoes-chance-reproduce 10;20
end

;; initalize the humans and bug agents
to create-agents
  ; create humans
  create-humans human-capacity [
    move-to-empty-one-of world-patches
    set size 1
    set shape "person"
    set infected-time 0
    set infected? false
    set thinks-infected? false
    set-human-lifespan
    set age random lifespan
    set sex "f"
    set pregnant? false
    set pregnancy-time 0
    set antimalarial-drug-count 0
  ]

  ; create mosquitoes
  create-mosquitoes mosquitoes-capacity[
    move-to-empty-one-of world-patches
    set size 0.7
    set shape "bug"
    set infected? false
    set pregnant? false
    set sex "f"
    ;set lifespan 30
    set-mosquito-lifespan
    set age random lifespan
    set pregnancy-time 0
    set bloodfed? false
  ]

  ask n-of (mosquitoes-capacity * (50 / 100)) mosquitoes
  [set sex "m"]

  ask n-of (human-capacity * (50 / 100)) humans
  [set sex "m"]

  ask n-of (mosquitoes-capacity * (inital-mosquitoes-infected / 100)) mosquitoes
  [set infected? true]

  ask n-of (human-capacity * (inital-humans-infected / 100)) humans
  [
    human-infection
    set infected-time random time-to-symptoms ;as infected assign a random infected time value to begin with
  ]
end

;; Handles which movement methods should be called for turtles.
to move
  ask humans [
    ; there infected, think there infected and have no pills left
    ifelse (antimalarial-drug-count = 0 and ((infected? and thinks-infected?) or random 100 < hospital-visit-chance) and count hospital-patches > count turtles-on hospital-patches)
      [ move-to-empty-one-of hospital-patches ]
      [ move-to-empty-one-of world-patches ]
  ]

  ask mosquitoes [
    move-to one-of world-patches
  ]
end


;; move turtles to location
to move-to-empty-one-of [locations]  ;; turtle procedure
  move-to one-of locations
  while [any? other turtles-here] [
    move-to one-of locations
  ]
end

to bloodfeed
  ask mosquitoes with [ (sex = "f") and pregnant? and (any? humans-here) ] [
    ifelse random 100 < 15
    [
      die
    ]
    [
      set bloodfed? true
      infection
    ]
  ]
end

to infection
  if ((infected?)) [ ;and random 100 < infection-chance
    ask (one-of humans-here)[
      if not infected? and (antimalarial-drug-count = 0 or random 100  < 100 - drug-efficacy) ;; ensure the chosen human is not infected already, 90% less likely to get malaria if taking pills.
      [
        ;if human has 1 or more pills then
        human-infection
        ;; have drugs?
        if antimalarial-drug-count > 0
        [
          set current-infections current-infections + 1
        ]
      ]
    ]
  ]

  if ((not infected?) and (any? (humans-on self) with [infected?])) [ ;and random 100 < infection-chance
    set infected? true
    set current-infections current-infections + 1
  ]
end

to human-infection
  set infected? true
  set time-to-symptoms (min-symptoms-days + random (max-symptoms-days - min-symptoms-days))
end

to update-infected-length
  ask humans [
    ifelse infected?
      [ set infected-time (infected-time + 1) ]
      [ set infected-time 0 ]
  ]
end

to check-infected
  ask humans [
    ifelse infected-time >= time-to-symptoms
      [ set thinks-infected? true ]
      [ set thinks-infected? false ]
  ]
end


;; update the display, to change the humans and bugs colors
to update-display
  ;; change human colors
  ask humans[
    ifelse infected?
      [set color red]
      [set color green]
  ]

  ;; change mosquitoes colors
  ask mosquitoes[
    ifelse infected?
      [set color red]
      [set color brown]
  ]
end

;set mosquito lifespan, the max time the mosqutio can be alive for
to set-mosquito-lifespan
  set lifespan (mosquito-min-age + random (mosquito-max-age - mosquito-min-age))
end

;set human lifespan, the max time the mosqutio can be alive for
to set-human-lifespan
  set lifespan (human-min-age + random (human-max-age - human-min-age))
end

; increase the age of the turtle
to get-older
  set age age + 1 ;; inc age
end

; die of natural causes. exceeded life expectancy
to die-naturally
  ask humans
  [
    if age > lifespan
    [
      set count-human-natural-deaths count-human-natural-deaths + 1
      die
    ]
  ]
  ask mosquitoes
  [
    if age > lifespan
    [
      die
    ]
  ]
end

; if human is infected, kill based on chance
to recover-or-die
  ask humans with [ (infected?) ]
  [
    let risk-factor 1
    if age <= 5 * 365
    [set risk-factor 2]

    if infected-time * risk-factor > duration
    [if random-float 100 > recovery-chance
      [
        set count-human-malaria-deaths count-human-malaria-deaths + 1
        die
      ]
    ]
  ]
end

to reproduce
  ask humans with [sex = "f" and age >= 18 * 365] [
    if (random-float 100 < humans-chance-reproduce) and not pregnant?
    [set pregnant? true ]
  ]

  ask mosquitoes with [sex = "f"] [
    if random-float 100 < mosquitoes-chance-reproduce and not pregnant?
    [set pregnant? true]
  ]
end

to birth
  ask humans with [ (pregnant?) ] [
    ifelse count humans < humans-max-capacity and pregnancy-time = 280
    [ hatch 1
      [ set age 1
        set shape "person"
        set infected-time 0
        set infected? infected?

        ifelse random 100 < 50
          [set sex "f"]
          [set sex "m"]

        set pregnant? false
        set pregnancy-time 0
        set thinks-infected? false
        set-human-lifespan
      ]
      set pregnancy-time 0
      set pregnant? false
      ]
  [ set pregnancy-time (pregnancy-time + 1) ]
  ]

  ask mosquitoes with [ (pregnant?) ][

    let hatch-eggs 1
    if bloodfed?
    [set hatch-eggs 10]

    ifelse count mosquitoes < mosquitoes-max-capacity and pregnancy-time = 5;14
    [ hatch hatch-eggs
      [
        set size 0.7
        set shape "bug"
        set infected? infected?
        set pregnancy-time 0
        set pregnant? false

        ifelse random 100 < 50
          [set sex "f"]
          [set sex "m"]

        set-mosquito-lifespan
        set age 1
        set bloodfed? false
      ]
      set pregnancy-time 0
      set pregnant? false
    ]
    [ set pregnancy-time (pregnancy-time + 1) ]
  ]
end


;;; Drug-related

to get-drugs
  ask humans-on hospital-patches [
    set antimalarial-drug-count 14

    if infected?
    [
     set current-infections current-infections + 1
    ]
  ]
end

to consume-drugs
  ask humans with [ antimalarial-drug-count > 0 ] [
    if (antimalarial-drug-count = 1 and random 100 < drug-efficacy)   ;TODO change this to a better calculation based on age and drug resistance.
    [
      set infected? false
    ]
    set antimalarial-drug-count (antimalarial-drug-count - 1)
  ]
end

;; change the counters for monitoring the current and previous generation infection rates
to set-drug-generation-counters
  if ticks mod malaria-generation-length = 0
  [
    ; assign drug resitance for current level of malaria.
    ;set drug-efficacy ? (human-min-age + random (human-max-age - human-min-age))
    ifelse current-infections < previous-infections
    [ set drug-efficacy drug-efficacy - random min-resistance-jump ]
    [ set drug-efficacy drug-efficacy - (min-resistance-jump + random (max-resistance-jump - min-resistance-jump))]

    if drug-efficacy < 0
    [ set drug-efficacy 0 ]

    set previous-infections current-infections
    set current-infections 0
  ]

  if ticks mod replacement-drug-days = 0
  [
    set drug-efficacy 90
  ]
end


;;; Monitors

to-report infected-humans-count
  report (count humans with [infected?])
end

to-report infected-mosquitoes-count
  report (count mosquitoes with [infected?])
end

to-report healthy-humans-count
  report (count humans with [infected? = false])
end

to-report alive-humans-count
  report (count humans)
end

to-report female-humans-count
  report (count humans with [sex = "f"])
end

to-report male-humans-count
  report (count humans with [sex = "m"])
end

to-report pregnant-humans-count
  report (count humans with [pregnant? = true])
end

to-report alive-mosquitoes-count
  report (count mosquitoes)
end

to-report female-mosquitoes-count
  report (count mosquitoes with [sex = "f"])
end

to-report male-mosquitoes-count
  report (count mosquitoes with [sex = "m"])
end

to-report pregnant-mosquitoes-count
  report (count mosquitoes with [pregnant? = true])
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;Questions/Unknowns;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


; calculate drug resistance? preportion of infections treated by drug, number of malaria clones per number
@#$#@#$#@
GRAPHICS-WINDOW
432
10
1252
831
-1
-1
24.61
1
10
1
1
1
0
1
1
1
-16
16
-16
16
1
1
1
ticks
30.0

BUTTON
17
50
80
83
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
17
97
189
130
human-capacity
human-capacity
2
humans-max-capacity
200.0
1
1
NIL
HORIZONTAL

SLIDER
18
137
190
170
mosquitoes-capacity
mosquitoes-capacity
2
mosquitoes-max-capacity
148.0
1
1
NIL
HORIZONTAL

SLIDER
13
274
206
307
inital-humans-infected
inital-humans-infected
0
100
52.0
1
1
%
HORIZONTAL

SLIDER
15
316
207
349
inital-mosquitoes-infected
inital-mosquitoes-infected
0
100
30.0
1
1
%
HORIZONTAL

BUTTON
92
50
155
83
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
14
426
122
471
Infected Humans
infected-humans-count
17
1
11

MONITOR
13
483
139
528
Infected Mosquitoes
infected-mosquitoes-count
17
1
11

BUTTON
93
11
156
44
Step
step
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
16
185
207
218
duration
duration
0
200
69.0
1
1
days
HORIZONTAL

SLIDER
13
227
205
260
recovery-chance
recovery-chance
0
100
19.0
1
1
%
HORIZONTAL

MONITOR
15
374
123
419
Healthy Humans
healthy-humans-count
0
1
11

PLOT
12
535
380
831
Populations
days
agents
0.0
100.0
0.0
100.0
true
true
"" ""
PENS
"infected" 1.0 0 -2674135 true "" "plot count humans with [infected?]"
"healthy" 1.0 0 -10899396 true "" "plot count humans with [not infected?]"
"mosquitoes" 1.0 0 -6459832 true "" "plot count mosquitoes"

INPUTBOX
171
400
326
460
min-symptoms-days
20.0
1
0
Number

INPUTBOX
171
468
326
528
max-symptoms-days
22.0
1
0
Number

MONITOR
1334
70
1484
115
NIL
female-humans-count
17
1
11

MONITOR
1334
122
1485
167
NIL
male-humans-count
17
1
11

MONITOR
1332
229
1484
274
NIL
female-mosquitoes-count
17
1
11

MONITOR
1333
283
1485
328
NIL
male-mosquitoes-count
17
1
11

MONITOR
1496
71
1661
116
NIL
pregnant-humans-count
17
1
11

MONITOR
1497
229
1663
274
NIL
pregnant-mosquitoes-count
17
1
11

MONITOR
1334
16
1484
61
NIL
alive-humans-count
17
1
11

MONITOR
1332
176
1485
221
NIL
alive-mosquitoes-count
17
1
11

SLIDER
208
98
380
131
infection-chance
infection-chance
0
100
84.0
1
1
%
HORIZONTAL

INPUTBOX
1284
344
1439
404
mosquito-min-age
10.0
1
0
Number

INPUTBOX
1285
411
1440
471
mosquito-max-age
25.0
1
0
Number

INPUTBOX
1443
345
1598
405
human-min-age
10000.0
1
0
Number

INPUTBOX
1444
410
1599
470
human-max-age
22265.0
1
0
Number

INPUTBOX
232
150
387
210
malaria-generation-length
100.0
1
0
Number

SLIDER
226
313
398
346
hospital-visit-chance
hospital-visit-chance
0
100
11.0
1
1
NIL
HORIZONTAL

INPUTBOX
232
214
387
274
replacement-drug-days
200.0
1
0
Number

INPUTBOX
1285
478
1440
538
min-resistance-jump
10.0
1
0
Number

INPUTBOX
1442
476
1597
536
max-resistance-jump
25.0
1
0
Number

PLOT
1288
565
1702
810
Deaths
days
death
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"natural-death" 1.0 0 -13345367 true "" "plot count-human-natural-deaths"
"malaria-death" 1.0 0 -2674135 true "" "plot count-human-malaria-deaths"

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

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

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
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
