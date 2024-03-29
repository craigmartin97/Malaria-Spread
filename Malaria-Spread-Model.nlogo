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
  drug-efficacy ;; should be between 0 and 90%. This number reduces as Malaria becomes more resistant.
  count-human-natural-deaths ;; tracking the number of natural human deaths.
  count-human-malaria-deaths ;; tracking the number of human deaths by malaria.
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
]

;; mosquitoes agents only
mosquitoes-own[
  bloodfeed-counter ;; days until next feed, only females when pregnant.
  bloodfed? ;; has the mosquito blood fed
]

;; initalize the interface and create enviroment
to setup
  clear-all
  set drug-efficacy 90 ;; antimalarial drugs have a 90% chance of preventing and curing malaria.
  setup-global-vars
  create-world  ;;create humans and mosquitoes
  create-agents
  update-display
  reset-ticks
end

;; single iteration of go
to step
  go
end

;; setup global vars, set mosquito and human capacity
to setup-global-vars
  set mosquitoes-max-capacity 500
  set humans-max-capacity 300
end

;; start simulation
to go
  ask turtles[
    ;ageing
    get-older ; inc turtle age and check if should die
    die-naturally
  ]

  ; drug efficacy
  set-drug-generation-counters

  ; hospital
  get-drugs
  consume-drugs
  move
  recover-or-die

  ; birthing
  reproduce
  birth

  ;infection
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

  ; set half mosquitoes sex to male
  ask n-of (mosquitoes-capacity * (50 / 100)) mosquitoes
  [set sex "m"]

  ; set half humans to male
  ask n-of (human-capacity * (50 / 100)) humans
  [set sex "m"]

  ; set percent of mosquitoes to infected
  ask n-of (mosquitoes-capacity * (inital-mosquitoes-infected / 100)) mosquitoes
  [set infected? true]

  ; set percent of humans to infected
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

;; female, pregnant mosquito attempts to feed from human
to bloodfeed
  ask mosquitoes with [ (sex = "f") and pregnant? and (any? humans-here) ] [
    ifelse random 100 < 15
    [
      die ; chance of death, incase human kills mosquito
    ]
    [
      ; successfully bloodfed, potentially infect the human
      set bloodfed? true
      infection
    ]
  ]
end

;; decide if the infection is transmitted between human and mosquito
to infection
  if ((infected?)) [ ;and random 100 < infection-chance
    ask (one-of humans-here)[
      if not infected? and (antimalarial-drug-count = 0 or random 100  < 100 - drug-efficacy) ;; ensure the chosen human is not infected already, 90% less likely to get malaria if taking pills.
      [
        human-infection
        ;if human has 1 or more pills then
        if antimalarial-drug-count > 0
        [
          set current-infections current-infections + 1
        ]
      ]
    ]
  ]

  ; if the human is infected, the bloodfeeding mosquito can get infected.
  if ((not infected?) and (any? (humans-on self) with [infected?])) [
    set infected? true
    set current-infections current-infections + 1
  ]
end

;; infect a human and assign time to symptoms
to human-infection
  set infected? true
  set time-to-symptoms (min-symptoms-days + random (max-symptoms-days - min-symptoms-days))
end

;; set the length of time the human has been infected for
to update-infected-length
  ask humans [
    ifelse infected?
      [ set infected-time (infected-time + 1) ]
      [ set infected-time 0 ]
  ]
end

;;set the thinks infected based on if symptoms are showing
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

;; set mosquito lifespan, the max time the mosqutio can be alive for
to set-mosquito-lifespan
  set lifespan (mosquito-min-age + random (mosquito-max-age - mosquito-min-age))
end

;; set human lifespan, the max time the mosqutio can be alive for
to set-human-lifespan
  set lifespan (human-min-age + random (human-max-age - human-min-age))
end

;; increase the age of the turtle
to get-older
  set age age + 1 ;; inc age
end

;; die of natural causes. exceeded life expectancy
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

;; if human is infected, kill based on chance
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

;; random chance for mosquitoes and humans to reproduce
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

;; give birth to a new turtles and introduce to the world
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

;; if in the hospital get 14 anti-malaria drugs, adds one to current infections
to get-drugs
  ask humans-on hospital-patches [
    set antimalarial-drug-count 14

    if infected?
    [
     set current-infections current-infections + 1
    ]
  ]
end

;; make the human consume one of the drugs they are holding
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
    [ set drug-efficacy drug-efficacy - (low-resistance-multiplier * current-infections) ]
    [ set drug-efficacy drug-efficacy - (high-resistance-multiplier * current-infections) ]

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
@#$#@#$#@
GRAPHICS-WINDOW
373
10
1252
890
-1
-1
26.4
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
16
13
79
46
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
16
54
188
87
human-capacity
human-capacity
2
humans-max-capacity
163.0
1
1
NIL
HORIZONTAL

SLIDER
194
54
366
87
mosquitoes-capacity
mosquitoes-capacity
2
mosquitoes-max-capacity
240.0
1
1
NIL
HORIZONTAL

SLIDER
15
96
189
129
inital-humans-infected
inital-humans-infected
0
100
30.0
1
1
%
HORIZONTAL

SLIDER
195
96
368
129
inital-mosquitoes-infected
inital-mosquitoes-infected
0
100
1.0
1
1
%
HORIZONTAL

BUTTON
91
13
154
46
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
1370
107
1478
152
Infected Humans
infected-humans-count
17
1
11

MONITOR
1482
107
1608
152
Infected Mosquitoes
infected-mosquitoes-count
17
1
11

BUTTON
168
14
231
47
step
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
177
192
210
duration
duration
0
200
160.0
1
1
days
HORIZONTAL

SLIDER
16
137
191
170
recovery-chance
recovery-chance
0
100
92.0
1
1
%
HORIZONTAL

MONITOR
1257
108
1365
153
Healthy Humans
healthy-humans-count
0
1
11

PLOT
1272
340
1688
636
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
14
220
133
280
min-symptoms-days
14.0
1
0
Number

INPUTBOX
142
220
261
280
max-symptoms-days
50.0
1
0
Number

MONITOR
1569
12
1719
57
NIL
female-humans-count
17
1
11

MONITOR
1412
11
1563
56
NIL
male-humans-count
17
1
11

MONITOR
1569
60
1721
105
NIL
female-mosquitoes-count
17
1
11

MONITOR
1413
60
1565
105
NIL
male-mosquitoes-count
17
1
11

MONITOR
1724
12
1889
57
NIL
pregnant-humans-count
17
1
11

MONITOR
1724
61
1890
106
NIL
pregnant-mosquitoes-count
17
1
11

MONITOR
1258
11
1408
56
NIL
alive-humans-count
17
1
11

MONITOR
1257
59
1410
104
NIL
alive-mosquitoes-count
17
1
11

INPUTBOX
14
287
134
347
mosquito-min-age
10.0
1
0
Number

INPUTBOX
141
285
262
345
mosquito-max-age
25.0
1
0
Number

INPUTBOX
13
349
135
409
human-min-age
10000.0
1
0
Number

INPUTBOX
141
349
262
409
human-max-age
22265.0
1
0
Number

INPUTBOX
12
479
170
539
malaria-generation-length
200.0
1
0
Number

SLIDER
196
137
369
170
hospital-visit-chance
hospital-visit-chance
0
100
95.0
1
1
NIL
HORIZONTAL

INPUTBOX
176
478
331
538
replacement-drug-days
2000.0
1
0
Number

INPUTBOX
12
414
135
474
low-resistance-multiplier
0.002
1
0
Number

INPUTBOX
143
414
263
474
high-resistance-multiplier
0.008
1
0
Number

PLOT
1274
644
1688
889
Deaths
days
death
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"natural-death" 1.0 0 -13345367 true "" "plot count-human-natural-deaths"
"malaria-death" 1.0 0 -2674135 true "" "plot count-human-malaria-deaths"

MONITOR
1257
157
1344
202
drug-efficacy
drug-efficacy
0
1
11

MONITOR
1350
157
1461
202
current-infections
current-infections
0
1
11

MONITOR
1466
157
1584
202
previous-infections
previous-infections
0
1
11

MONITOR
1257
206
1423
251
total-human-natural-deaths
count-human-natural-deaths
0
1
11

MONITOR
1428
206
1620
251
total-human-malaria-deaths
count-human-malaria-deaths
0
1
11

PLOT
1655
114
1871
254
Drug Efficacy
days
drug-efficacy
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"Drug Efficacy" 1.0 0 -2674135 true "" "plot drug-efficacy"

@#$#@#$#@
## WHAT IS IT?

This model looks at a population of Humans and Mosquitoes and how Malaria can become resistant to drugs based on the frequency of a communities drug usage. Malaria is transmitted during the bloodfeeding process which female mosquitoes perform during pregnancy.

## HOW IT WORKS

Other:
- Each tick represents a time period of 1 day.
- Drug efficacy is reduced every number of ticks defined by malaria-generation-length. If more infections occured in the previous generation of malaria, the low-resistance-multiplier is used. Else, the high-resistance-multiplier is used. The applied multiplier multiplied by the number of current infections is taken away from the drug efficacy.
- Drug efficacy is reset to 90 every number of ticks defined by replacement-drug-days.

Mosquitoes and Humans:
- Will move to a random location each tick.
- Can get pregnant and give birth.
- Can get infected by Malaria.
- Assigned a maximum lifespan at birth.
- Age is tracked in days.
- Coloured red when infected.

Mosquitoes:
- Coloured brown when not infected.
- No more Mosquitoes can be hatched if >= 500 exist.
- Will move to any location regardless of what is currently on a patch.
- Female Mosquitoes, when pregnant, will bloodfeed on humans if they land on them.
- During bloodfeeding, an infected Mosquito may infect the human.
- During bloodfeeding, a healthy Mosquito may contract the disease if the human is infected.

Humans:
- Coloured green when not infected.
- No more Humans can be hatched if >= 300 exist.
- Will only move to empty patches (Mosquitoes move on top after).
- Will visit the hospital if they know they are infected or randomly based on the hospital-visit-chance slider.
- Upon visiting the hospital, gets 14 antimalarial drugs.
- Once all antimalarial drugs are taken while infected, humans have a chance to be cured based on drug efficacy.
- If bloodfed on by an infected mosquito, humans have a chance to avoid infection based on drug efficacy.
- Upon infection, time-to-symptoms is assigned and the human will recognise that they have malaria after this many ticks pass.
- Humans have a higher risk factor of dying to malaria if they are < 5 years old.

## HOW TO USE IT

Buttons:
- setup	: Creates and assigns attributes of the Global Scope, Patches, Humans and Mosquitoes.
- go	: Continuosly runs the simulation.
- step	: Calls 'go' a single time.

Sliders:
- (human/mosquitoes)-capacity :	Sets the number of humans/mosquitoes to create upon 'setup'.
- initial-(humans/mosquitoes)-infected : Sets the % of the created humans/mosquitoes to create as infected upon 'setup'.
- recovery-chance : The chance that a human survives after they have been infected long enough to be killed by Malaria.
- hospital-visit-chance : The chance that a human will visit the hospital for antimalarial drugs regardless of whether they are infected or not.
- duration : The number of days before a Malarial infection becomes lethal to its host.

Inputs:
- (min/max)-symptoms-days : The range of days before symptoms can show up for an infected Human. A random number within this range is selected upon infection.
- (min/max)-(mosquito/human)-age : The range of days that the turtles lifespan can be inbetween. A random number within this range is selected upon creation.
- low-resistance-multiplier : The multiplier of resistance that is applied to the number of current-infections, if current-infections > previous-infections, when a new Malaria generation occurs.
- high-resistance-multiplier : The multiplier of resistance that is applied to the number of current-infections, if current-infections > previous-infections, when a new Malaria generation occurs.
- malaria-generation-length : The number of days representing how long it takes Malaria to evolve into a new generation with improved drug resistance.
- replacement-drug-days : The number of days representing how long it takes a new antimalarial drug to be released.

Monitors:
- alive-(humans/mosquitoes)-count : Tracks the number of alive humans and mosquitoes.
- male-(humans/mosquitoes)-count : Tracks the number of alive male humans and mosquitoes.
- female-(humans/mosquitoes)-count : Tracks the number of alive female humans and mosquitoes.
- pregnant-(humans/mosquitoes)-count : Tracks the number of alive pregnant humans and mosquitoes.
- Healthy-Humans : Tracks the numer of alive, not infected, humans.
- Infected (Humans/Mosquitoes) : Tracks the number of alive, infected, humans/mosquitoes.
- drug-efficacy : The chance that antimalarial drug users will avoid an infection or be cured of an infection.
- current-infections : The number of malaria infections created in the current malaria generation.
- previous-infections : The number of malaria infections created in the previous malaria generation.
- total-human-(natural/malaria)-deaths : The total number of human deaths by malaria or natural causes.

Plots:
- Drug Efficacy : View the drug efficacy throughout a simulation.
- Populations : View the number of healthy/infected humans and the number of mosquitoes throughout a simulation.
- Deaths : View the number of deaths by malaria and natural causes throughout a simulation.

## THINGS TO NOTICE

There are three potential endings for the simulation:
1. Human and Mosquito populations reach their capacity (300 and 500 respectively).
2. The Human population gets low enough that the Mosquitoes can no longer bloodfeed and all die out. After this, the Human population will rebuild.
3. The drug efficacy reduces heavily and both the Human and Mosquito populations get wiped out.

## THINGS TO TRY

Test configurations to try:
Small duration, high recovery chance, low hospital visit chance
Small duration low recovery chance, low hospital visit chance
High duration low recovery chance, low hospital visit chance
High duration, high recovery chance, low hospital visit chance
Small duration, high recovery chance, high hospital visit chance
Small duration low recovery chance, high hospital visit chance
High duration low recovery chance, high hospital visit chance
High duration, high recovery chance, high hospital visit chance

Low initial humans infected, low initial mosquito infected
high initial humans infected, high initial mosquito infected
high initial humans infected, low initial mosquito infected
Low initial humans infected, high initial mosquito infected


Low min symptoms days, low max symptoms days, high duration
Low min symptoms days, low max symptoms days, low duration

Change lifespans
Change resistance multipliers and malaria/drug lengths


## EXTENDING THE MODEL

One issue with the model is that the Mosquito population will grow rapidly due to the number of eggs that they can hatch. Finding a way to balance the birthing rates without having to supply a hard limit could make the simulation more interesting.

The paper referenced at the bottom of this Info page mentions that malaria can randomly mutate. Our model only allows for malaria to evolve over a fixed length but could be improved by varying this length and adding random mutations.

More risk factors should be introduced to the recover-or-die. Currently only young age is considered for the risk factor whereas more scienntifically proven risk factors could be included such as pregnancy and old age.

## RELATED MODELS

We used the following two models to learn NetLogo and to find relevant functionality for this model:
Sample Models -> Biology -> AIDS
Sample Models -> Biology -> Virus.

## CREDITS AND REFERENCES

The primary research paper which inspired this work:
Intensity of malaria transmission and the evolution of drug resistance - https://www.sciencedirect.com/science/article/pii/S0001706X05000847
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
NetLogo 6.0.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Low-Hospital-Chance" repetitions="3" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="200000"/>
    <exitCondition>count mosquitoes = 0 or count humans = 0</exitCondition>
    <metric>ticks</metric>
    <metric>count humans</metric>
    <metric>count mosquitoes</metric>
    <metric>drug-efficacy</metric>
    <metric>current-infections</metric>
    <metric>previous-infections</metric>
    <enumeratedValueSet variable="human-capacity">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hospital-visit-chance">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-symptoms-days">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inital-mosquitoes-infected">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-symptoms-days">
      <value value="22"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="replacement-drug-days">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-resistance-jump">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="malaria-generation-length">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recovery-chance">
      <value value="24"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="duration">
      <value value="36"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquito-min-age">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquitoes-capacity">
      <value value="148"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-max-age">
      <value value="22265"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-min-age">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-resistance-jump">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inital-humans-infected">
      <value value="52"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquito-max-age">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="High-Hospital-Chance" repetitions="3" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="200000"/>
    <exitCondition>count mosquitoes = 0 or count humans = 0</exitCondition>
    <metric>ticks</metric>
    <metric>count humans</metric>
    <metric>count mosquitoes</metric>
    <metric>drug-efficacy</metric>
    <metric>current-infections</metric>
    <metric>previous-infections</metric>
    <enumeratedValueSet variable="human-capacity">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hospital-visit-chance">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-symptoms-days">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inital-mosquitoes-infected">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-symptoms-days">
      <value value="22"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="replacement-drug-days">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-resistance-jump">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="malaria-generation-length">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recovery-chance">
      <value value="24"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="duration">
      <value value="36"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquito-min-age">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquitoes-capacity">
      <value value="148"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-max-age">
      <value value="22265"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-min-age">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-resistance-jump">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inital-humans-infected">
      <value value="52"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquito-max-age">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Low-Human-Population" repetitions="3" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="5000"/>
    <exitCondition>count mosquitoes = 0 or count humans = 0</exitCondition>
    <metric>ticks</metric>
    <metric>count humans</metric>
    <metric>count mosquitoes</metric>
    <metric>drug-efficacy</metric>
    <metric>current-infections</metric>
    <metric>previous-infections</metric>
    <enumeratedValueSet variable="high-resistance-multiplier">
      <value value="0.008"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="low-resistance-multiplier">
      <value value="0.002"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-capacity">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-symptoms-days">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inital-mosquitoes-infected">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-symptoms-days">
      <value value="22"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hospital-visit-chance">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="replacement-drug-days">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="malaria-generation-length">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recovery-chance">
      <value value="67"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="duration">
      <value value="130"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquito-min-age">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquitoes-capacity">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inital-humans-infected">
      <value value="29"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-max-age">
      <value value="22265"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquito-max-age">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-min-age">
      <value value="10000"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Small-Duration-High-Recovery-Low-Hospital-Chance" repetitions="3" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="5000"/>
    <exitCondition>count mosquitoes = 0 or count humans = 0</exitCondition>
    <metric>ticks</metric>
    <metric>count humans</metric>
    <metric>count mosquitoes</metric>
    <metric>drug-efficacy</metric>
    <metric>current-infections</metric>
    <metric>previous-infections</metric>
    <enumeratedValueSet variable="high-resistance-multiplier">
      <value value="0.008"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="low-resistance-multiplier">
      <value value="0.002"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-capacity">
      <value value="201"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-symptoms-days">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-symptoms-days">
      <value value="22"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hospital-visit-chance">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inital-mosquitoes-infected">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="replacement-drug-days">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="malaria-generation-length">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recovery-chance">
      <value value="94"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="duration">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquito-min-age">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquitoes-capacity">
      <value value="170"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inital-humans-infected">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-max-age">
      <value value="22265"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-min-age">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquito-max-age">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Small-Duration-Low-Recovery-Low-Hospital-Chance" repetitions="3" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="5000"/>
    <exitCondition>count mosquitoes = 0 or count humans = 0</exitCondition>
    <metric>ticks</metric>
    <metric>count humans</metric>
    <metric>count mosquitoes</metric>
    <metric>drug-efficacy</metric>
    <metric>current-infections</metric>
    <metric>previous-infections</metric>
    <enumeratedValueSet variable="high-resistance-multiplier">
      <value value="0.008"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="low-resistance-multiplier">
      <value value="0.002"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-capacity">
      <value value="201"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-symptoms-days">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-symptoms-days">
      <value value="22"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hospital-visit-chance">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inital-mosquitoes-infected">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="replacement-drug-days">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="malaria-generation-length">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recovery-chance">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="duration">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquito-min-age">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquitoes-capacity">
      <value value="170"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inital-humans-infected">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-max-age">
      <value value="22265"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-min-age">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquito-max-age">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="High-Duration-Low-Recovery-Low-Hosptail-Chance" repetitions="3" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="5000"/>
    <exitCondition>count mosquitoes = 0 or count humans = 0</exitCondition>
    <metric>ticks</metric>
    <metric>count humans</metric>
    <metric>count mosquitoes</metric>
    <metric>drug-efficacy</metric>
    <metric>current-infections</metric>
    <metric>previous-infections</metric>
    <enumeratedValueSet variable="high-resistance-multiplier">
      <value value="0.008"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="low-resistance-multiplier">
      <value value="0.002"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-capacity">
      <value value="201"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-symptoms-days">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-symptoms-days">
      <value value="22"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hospital-visit-chance">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inital-mosquitoes-infected">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="replacement-drug-days">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="malaria-generation-length">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recovery-chance">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="duration">
      <value value="174"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquito-min-age">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquitoes-capacity">
      <value value="170"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inital-humans-infected">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-max-age">
      <value value="22265"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-min-age">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquito-max-age">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="High-Duration-High-Recovery-Low-Hospital-Chance" repetitions="3" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="5000"/>
    <exitCondition>count mosquitoes = 0 or count humans = 0</exitCondition>
    <metric>ticks</metric>
    <metric>count humans</metric>
    <metric>count mosquitoes</metric>
    <metric>drug-efficacy</metric>
    <metric>current-infections</metric>
    <metric>previous-infections</metric>
    <enumeratedValueSet variable="high-resistance-multiplier">
      <value value="0.008"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="low-resistance-multiplier">
      <value value="0.002"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-capacity">
      <value value="201"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-symptoms-days">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-symptoms-days">
      <value value="22"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hospital-visit-chance">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inital-mosquitoes-infected">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="replacement-drug-days">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="malaria-generation-length">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recovery-chance">
      <value value="89"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="duration">
      <value value="174"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquito-min-age">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquitoes-capacity">
      <value value="170"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inital-humans-infected">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-max-age">
      <value value="22265"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-min-age">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquito-max-age">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Small-Duration-High-Recovery-High-Hospital-Chance" repetitions="3" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <exitCondition>count mosquitoes = 0 or count humans = 0</exitCondition>
    <metric>ticks</metric>
    <metric>count humans</metric>
    <metric>count mosquitoes</metric>
    <metric>drug-efficacy</metric>
    <metric>current-infections</metric>
    <metric>previous-infections</metric>
    <enumeratedValueSet variable="high-resistance-multiplier">
      <value value="0.008"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="low-resistance-multiplier">
      <value value="0.002"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-capacity">
      <value value="201"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-symptoms-days">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-symptoms-days">
      <value value="22"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hospital-visit-chance">
      <value value="91"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inital-mosquitoes-infected">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="replacement-drug-days">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="malaria-generation-length">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recovery-chance">
      <value value="89"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="duration">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquito-min-age">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquitoes-capacity">
      <value value="170"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inital-humans-infected">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-max-age">
      <value value="22265"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-min-age">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquito-max-age">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Small-Duration-Low-Recovery-High-Hospital-Chance" repetitions="3" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="5000"/>
    <exitCondition>count mosquitoes = 0 or count humans = 0</exitCondition>
    <metric>ticks</metric>
    <metric>count humans</metric>
    <metric>count mosquitoes</metric>
    <metric>drug-efficacy</metric>
    <metric>current-infections</metric>
    <metric>previous-infections</metric>
    <enumeratedValueSet variable="high-resistance-multiplier">
      <value value="0.008"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="low-resistance-multiplier">
      <value value="0.002"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-capacity">
      <value value="201"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-symptoms-days">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-symptoms-days">
      <value value="22"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hospital-visit-chance">
      <value value="91"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inital-mosquitoes-infected">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="replacement-drug-days">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="malaria-generation-length">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recovery-chance">
      <value value="14"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="duration">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquito-min-age">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquitoes-capacity">
      <value value="170"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inital-humans-infected">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-max-age">
      <value value="22265"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-min-age">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquito-max-age">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="High-Duration-Low-Recovery-HighHospital" repetitions="3" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="5000"/>
    <exitCondition>count mosquitoes = 0 or count humans = 0</exitCondition>
    <metric>ticks</metric>
    <metric>count humans</metric>
    <metric>count mosquitoes</metric>
    <metric>drug-efficacy</metric>
    <metric>current-infections</metric>
    <metric>previous-infections</metric>
    <enumeratedValueSet variable="high-resistance-multiplier">
      <value value="0.008"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="low-resistance-multiplier">
      <value value="0.002"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-capacity">
      <value value="201"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-symptoms-days">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-symptoms-days">
      <value value="22"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hospital-visit-chance">
      <value value="91"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inital-mosquitoes-infected">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="replacement-drug-days">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="malaria-generation-length">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recovery-chance">
      <value value="14"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="duration">
      <value value="160"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquito-min-age">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquitoes-capacity">
      <value value="170"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inital-humans-infected">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-max-age">
      <value value="22265"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-min-age">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquito-max-age">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="High-Duration-High-Recovery-High-Hospital-Chance" repetitions="3" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="5000"/>
    <exitCondition>count mosquitoes = 0 or count humans = 0</exitCondition>
    <metric>ticks</metric>
    <metric>count humans</metric>
    <metric>count mosquitoes</metric>
    <metric>drug-efficacy</metric>
    <metric>current-infections</metric>
    <metric>previous-infections</metric>
    <enumeratedValueSet variable="high-resistance-multiplier">
      <value value="0.008"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="low-resistance-multiplier">
      <value value="0.002"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-capacity">
      <value value="201"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-symptoms-days">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-symptoms-days">
      <value value="22"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hospital-visit-chance">
      <value value="91"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inital-mosquitoes-infected">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="replacement-drug-days">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="malaria-generation-length">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recovery-chance">
      <value value="92"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="duration">
      <value value="160"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquito-min-age">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquitoes-capacity">
      <value value="170"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inital-humans-infected">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-max-age">
      <value value="22265"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-min-age">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquito-max-age">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Low-Human-InitPop-Low-Los-InitPop" repetitions="3" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="5000"/>
    <exitCondition>count mosquitoes = 0 or count humans = 0</exitCondition>
    <metric>ticks</metric>
    <metric>count humans</metric>
    <metric>count mosquitoes</metric>
    <metric>drug-efficacy</metric>
    <metric>current-infections</metric>
    <metric>previous-infections</metric>
    <enumeratedValueSet variable="high-resistance-multiplier">
      <value value="0.008"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="low-resistance-multiplier">
      <value value="0.002"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-capacity">
      <value value="32"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-symptoms-days">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-symptoms-days">
      <value value="22"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hospital-visit-chance">
      <value value="91"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inital-mosquitoes-infected">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="replacement-drug-days">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="malaria-generation-length">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recovery-chance">
      <value value="92"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="duration">
      <value value="160"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquito-min-age">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquitoes-capacity">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inital-humans-infected">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-max-age">
      <value value="22265"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-min-age">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquito-max-age">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Low-Human-InitPop-High-Mos-Init-Pop" repetitions="3" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="5000"/>
    <exitCondition>count mosquitoes = 0 or count humans = 0</exitCondition>
    <metric>ticks</metric>
    <metric>count humans</metric>
    <metric>count mosquitoes</metric>
    <metric>drug-efficacy</metric>
    <metric>current-infections</metric>
    <metric>previous-infections</metric>
    <enumeratedValueSet variable="high-resistance-multiplier">
      <value value="0.008"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="low-resistance-multiplier">
      <value value="0.002"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-capacity">
      <value value="32"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-symptoms-days">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-symptoms-days">
      <value value="22"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hospital-visit-chance">
      <value value="91"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inital-mosquitoes-infected">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="replacement-drug-days">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="malaria-generation-length">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recovery-chance">
      <value value="92"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="duration">
      <value value="160"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquito-min-age">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquitoes-capacity">
      <value value="433"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inital-humans-infected">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-max-age">
      <value value="22265"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-min-age">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquito-max-age">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Med-Human-Init-Pop-Low-Mos-InitPop" repetitions="8" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <exitCondition>count mosquitoes = 0 or count humans = 0</exitCondition>
    <metric>count turtles</metric>
    <metric>count humans</metric>
    <metric>count mosquitoes</metric>
    <metric>infected-mosquitoes-count</metric>
    <enumeratedValueSet variable="high-resistance-multiplier">
      <value value="0.008"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="low-resistance-multiplier">
      <value value="0.002"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-capacity">
      <value value="192"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-symptoms-days">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-symptoms-days">
      <value value="22"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hospital-visit-chance">
      <value value="91"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inital-mosquitoes-infected">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="replacement-drug-days">
      <value value="2000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="malaria-generation-length">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recovery-chance">
      <value value="92"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="duration">
      <value value="160"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquito-min-age">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquitoes-capacity">
      <value value="24"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inital-humans-infected">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-max-age">
      <value value="22265"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-min-age">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquito-max-age">
      <value value="25"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="1000-Malaria-Gen-5000-replacement-days" repetitions="3" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100000"/>
    <exitCondition>count humans = 0 or count mosquitoes = 0</exitCondition>
    <metric>count turtles</metric>
    <metric>count humans</metric>
    <metric>count mosquitoes</metric>
    <metric>count-human-malaria-deaths</metric>
    <metric>drug-efficacy</metric>
    <enumeratedValueSet variable="high-resistance-multiplier">
      <value value="0.008"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="low-resistance-multiplier">
      <value value="0.002"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-capacity">
      <value value="163"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-symptoms-days">
      <value value="14"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-symptoms-days">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hospital-visit-chance">
      <value value="91"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inital-mosquitoes-infected">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="replacement-drug-days">
      <value value="5000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="malaria-generation-length">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="recovery-chance">
      <value value="92"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="duration">
      <value value="160"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquito-min-age">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquitoes-capacity">
      <value value="240"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="inital-humans-infected">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-max-age">
      <value value="22265"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="human-min-age">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mosquito-max-age">
      <value value="25"/>
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
