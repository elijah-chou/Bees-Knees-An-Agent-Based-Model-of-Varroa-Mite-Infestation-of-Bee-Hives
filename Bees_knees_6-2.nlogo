extensions [time]
breed [bees bee]
breed [hives hive]
breed [ funcs func ]
funcs-own [ A1 B1 th]

globals [healthy-age sick-age healthy-energy sick-energy num-sick-bees num-safe-bees num-healthy-bees h] ;initiated in setup

patches-own [flower? infestedPatch? time]

bees-own [infested? sick? treated? safe? dist-to-goal returning-to-hive? goal energy add-energy? add-food? my-hive age food t-oil t-success th-success]

hives-own [food infestation-rate sp-oil sp-success th-oil pop-count protected? mite-1 mite-2]

to startup
  setup
end

to setup
  clear-all
  reset-ticks
  ask patches [ set pcolor rgb 72 180 120 ]
  set healthy-age 1056 ;about 22 days, where 1 tick is equal to 1/2 hour
  set sick-age 816 ;about 17 days, since DWV bees have reduced life spans (4.74 days less)
  set healthy-energy 100
  set sick-energy 80
  set h 1 / 48

  ;flower setup
  setup_flowers
  ask n-of starting-mite-count patches with [flower? = true] [set infestedPatch? true]

  ;bees setup
  set-default-shape hives "house"

  set-default-shape bees "bee"


  create-hives number_of_hives [set color rgb 255 152 66 setxy random-xcor random-ycor set size 5
  set food 0 ]
  layout-circle hives 25

  create-bees number_of_bees [
    set color yellow
    setxy random-xcor random-ycor
    set dist-to-goal 0
    set returning-to-hive? false
    set size 3
    set energy healthy-energy
    set age random-poisson healthy-age
    set sick? false
    set infested? false
    set food 0
    set treated? false]

  ;link bees to hives
  layout-circle bees 25
  ask bees [create-link-to one-of hives set my-hive [other-end] of one-of my-out-links update-goal]
  ; ask links [hide-link]
  ; to hide links later: " ask links [hide-link] "
  ; if want to link all bees to all hives " ask hives [ create-links-with bees]
  show count links

end

to go
  ask bees [
    fly
    get-infested
    bites-the-dust
    groom
    update-color
    revert
  ]
  ask bees with [infested? = true] [
    drop-mite
  ]
  ask hives [
    birth-larva
    lose-oil
    replenish-energy
    set pop-count count my-in-links
    set label floor mite-1
    if ticks mod (time_reapplication) = 0 [
      if add-thyme? [drop-thyme]
      if add-spearmint? [spearmint]
    ]
  ]
  runge
  tick
end

to setup_flowers
  ask n-of number_of_flowers patches [ set pcolor rgb 219 84 97 set flower? true]
  ask patches with [pcolor = rgb 219 84 97] [ask neighbors4 [set pcolor rgb 219 84 97 set flower? true]]
  ask n-of number_of_flowers patches [ set pcolor rgb 66 129 164 set flower? true]
  ask patches with [pcolor = rgb 66 129 164] [ask neighbors4 [set pcolor rgb 66 129 164 set flower? true]]
  ask n-of number_of_flowers patches [ set pcolor rgb 80 81 79 set flower? true]
  ask patches with [pcolor = rgb 80 81 79] [ask neighbors4 [set pcolor rgb 80 81 79 set flower? true]]
end

to fly
  ifelse returning-to-hive? = true
  [ set dist-to-goal [link-length] of one-of my-out-links ]
  [ set dist-to-goal [distance myself] of goal ]
  if dist-to-goal < 1 [update-goal]
  ifelse sick? = false [fd 1] [fd 0.9]
  set energy energy - 1
end

to update-goal
  let distance-to-hive [link-length] of one-of my-out-links
  ifelse (distance-to-hive < 1)
  [
    ;code to find new flower patch and set as goal from hive
    set goal one-of patches with [(flower? = true)] in-radius 50
    set heading (towards goal)
    set returning-to-hive? false
    set add-food? false
    let food-to-add food
    set food 0
    ifelse infested? = true [
      set infested? false
      ask hives-here [
        set food (food + food-to-add)
        set mite-1 (mite-1 + 1)
      ]
    ]
    [
      ask hives-here [
        set food (food + food-to-add)
      ]
    ]

  ]
  [
    ;code to return to hive or go to new flower patch after visiting a flower patch
    ifelse random-float 1 < 0.3 [set goal one-of patches with [(flower? = true)] in-radius 50 set returning-to-hive? false]
    [ set goal my-hive set returning-to-hive? true set add-food? true]
    set food food + 1
    set heading (towards goal)
  ]
end

to drop-mite
  if random-float 1 < 0.00001 [
    if [flower?] of patch-here = true [
      ask patch-here [set infestedPatch? true]
    ]
    set infested? false
  ]
end

to get-infested
    ifelse t-oil = 100 [
    set t-success (0.781)]
  [ if t-oil > 0
    [if (ticks mod 25) = 0 [set t-success t-success - 0.05]]]
  if [infestedPatch?] of patch-here = true [
    let prob 0.95
     if treated? = true [set prob 1 - t-success]
     if random-float 1 < prob [
      set infested? true
      set treated? false
      ask patch-here [set infestedPatch? false]
     ]
   ]
end

to replenish-energy
  ask bees with [sick? = false] in-radius 1 [ set energy healthy-energy ]
  ask bees with [sick? = true] in-radius 1 [ set energy sick-energy ]
end

to bites-the-dust ;temporarily removed chance_of_death so that all bees conform to average lifespans
  ifelse energy = 0 or age = 0 [die]
  [
    set age age - 1
  ]
end


to birth-larva
  ;command for hive to produce offspring, and uses adjustable number of eggs to determine # of offspring
  if (food >= 10) and (ticks mod 100) = 0 [
    let total-bees-produced (pop-count * (1 - (pop-count / carrying_capacity)))
    ifelse protected? = true [
      set num-safe-bees (total-bees-produced * sp-success)
      set num-sick-bees (total-bees-produced - num-safe-bees)
    ]
    [
      ifelse mite-1 < pop-count [ set infestation-rate mite-1 / pop-count ]
      [ set infestation-rate 1]
      set num-sick-bees (total-bees-produced * infestation-rate)
      set num-healthy-bees (total-bees-produced - num-sick-bees)
    ]
    ask patch-here [
      ;sprouts infested & sick bees
      sprout-bees num-sick-bees [
        create-link-to one-of hives-here
        set my-hive [other-end] of one-of my-out-links
        set infested? true
        set sick? true
        set returning-to-hive? false
        set size 3
        update-goal
        set age random-poisson sick-age
        set energy sick-energy
        set food 0]

      ;sprouts healthy bees
      sprout-bees num-healthy-bees [
        create-link-to one-of hives-here
        set my-hive [other-end] of one-of my-out-links
        set infested? false
        set sick? false
        set returning-to-hive? false
        set size 3
        update-goal
        set age random-poisson healthy-age
        set energy healthy-energy
        set food 0]

     ;sprouts safe bees
      sprout-bees num-safe-bees [
        create-link-to one-of hives-here
        set my-hive [other-end] of one-of my-out-links
        set infested? false
        set sick? false
        set returning-to-hive? false
        set safe? true
        set size 3
        update-goal
        set age random-poisson healthy-age
        set energy healthy-energy
        set food 0]
  ]
    set food food - 10
]
end

to runge
  ask hives [
  let this who
  ;k1 ----------------------
  ask patch 0 0 [
    sprout-funcs 1 [
      set A1 ( [ mite-1 ] of hive this )
      set B1 ( [ mite-2 ] of hive this )
      ifelse [th-oil] of hive this > 0
        [set th 1]
        [set th 0]
      hide-turtle
    ]
  ]
  ask one-of funcs [ fun ]
  let k1x ( [ A1 ] of one-of funcs )
  let k1y ( [ B1 ] of one-of funcs )
  ask one-of funcs [ die ]
  ;k2 -------------------------
  ask patch 0 0 [
    sprout-funcs 1 [
      set A1 ( [ mite-1 ] of hive this + h * k1x / 2 )
      set B1 ( [ mite-2 ] of hive this + h * k1y / 2 )
      ifelse [th-oil] of hive this > 0
        [set th 1]
        [set th 0]
      hide-turtle
    ]
  ]
  ask one-of funcs [ fun ]
  let k2x ( [ A1 ] of one-of funcs )
  let k2y ( [ B1 ] of one-of funcs )
  ask one-of funcs [ die ]
  ;k3 -------------------------
  ask patch 0 0 [
    sprout-funcs 1 [
      set A1 ( [ mite-1 ] of hive this + h * k2x / 2 )
      set B1 ( [ mite-2 ] of hive this + h * k2y / 2 )
      ifelse [th-oil] of hive this > 0
        [set th 1]
        [set th 0]
      hide-turtle
    ]
  ]
  ask one-of funcs [ fun ]
  let k3x ( [ A1 ] of one-of funcs )
  let k3y ( [ B1 ] of one-of funcs )
  ask one-of funcs [ die ]
  ;k4 -------------------------
  ask patch 0 0 [
    sprout-funcs 1 [
      set A1 ( [ mite-1 ] of hive this + h * k3x  )
      set B1 ( [ mite-2 ] of hive this + h * k3y  )
      ifelse [th-oil] of hive this > 0
        [set th 1]
        [set th 0]
      hide-turtle
    ]
  ]
  ask one-of funcs [ fun ]
  let k4x ( [ A1 ] of one-of funcs )
  let k4y ( [ B1 ] of one-of funcs )
  ask one-of funcs [ die ]

  set mite-1 ( mite-1 + ( 1 / 6 ) * h * ( k1x + 2 * k2x + 2 * k3x + k4x ))
  set mite-2 ( mite-2 + ( 1 / 6 ) * h * ( k1y + 2 * k2y + 2 * k3y + k4y ))

  ]
end

to fun ; this is were the system of ODE's is taken into account
  let x ((-1 / 9) * A1 - (1 / 28) * A1 + (1 / 2) * B1) ; This is the first equation (ie X')
  let y ((1 / 9) * A1 - (1 / 2) * B1 - (1 / 5) * B1 - th * B1 + 0.069 * A1)      ; Out of cell (ie Y')
  set A1 x                     ; this must be done like this otherwise B1 will be calculated using the new A1 when we need the old value of A1
  set B1 y
end

to groom
   if ([link-length] of one-of my-out-links < 1) [ if random-float 1 < 0.0001 [
    set infested? false
    ]
  ]
end

to drop-thyme
    ;thyme oil disorients mites and causes them to fall off adult bees (reproducing mites unaffected)
  set th-oil 100
  ifelse th-oil = 100 [
    ask link-neighbors with [([link-length] of one-of my-out-links < 1)] [
      set th-success (0.781)]
  ]
    [if th-oil > 0 [
    ask link-neighbors with [([link-length] of one-of my-out-links < 1)]
    [if (ticks mod 25) = 0 [set th-success th-success - 0.05]
    ]
  ]]

  if th-oil = 100 [
  ask link-neighbors with [([link-length] of one-of my-out-links < 1)] [
      if random-float 1 < th-success [
        set infested? false
        set treated? true
        set t-oil 100
        ;to see how effective this is too?
     ]
  ]
  ]
  if th-oil != 100 and th-oil > 0
    [ask link-neighbors with [([link-length] of one-of my-out-links < 1)] [
      if random-float 1 < th-success [
        set infested? false
        set treated? true
              ]
      ]
    ]

end

to spearmint
  ;spearmint oil helps prevent disease transmission from varroa mites to bees
    ;spearmint oil helps prevent disease transmission from varroa mites to bees
 set protected? true
   set sp-oil 100
ifelse sp-oil = 100
  [set sp-success (0.843)]
  [ if sp-oil > 0
    [if (ticks mod 25) = 0 [set sp-success sp-success - 0.05]]]

  end

to revert
   ask bees with [treated? = true][
    if t-oil = 0 [set treated? false]
  ]
end

to lose-oil
  if th-oil <= 100 [if (ticks mod 25) = 0 [set th-oil th-oil - 3]
  ]
  ask link-neighbors with [([link-length] of one-of my-out-links < 1)] [if t-oil <= 100 [if (ticks mod 25) = 0 [set t-oil t-oil - 3]
  ]]
   if sp-oil <= 100 [if (ticks mod 25) = 0 [set sp-oil sp-oil - 3]
  ]
  if sp-oil = 0 [set protected? false]

end

to update-color ;discuss whether to use or not
  ifelse treated? = true [set color blue] [
    if infested? = true and sick? = true [ set color magenta ]
    if infested? = true and sick? = false [ set color red ]
    if infested? = false and sick? = true [set color magenta ]
    if infested? = false and sick? = false [set color yellow ]
  ]
  if safe? = true [set color rgb 0 255 255]

end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
723
524
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
-50
50
-50
50
0
0
1
ticks
30.0

BUTTON
20
10
84
43
Setup
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

BUTTON
95
10
158
43
Go
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

SLIDER
15
50
187
83
number_of_hives
number_of_hives
0
25
3.0
1
1
NIL
HORIZONTAL

SLIDER
15
95
187
128
number_of_bees
number_of_bees
0
100
24.0
1
1
NIL
HORIZONTAL

SLIDER
15
185
187
218
number_of_flowers
number_of_flowers
0
100
26.0
1
1
NIL
HORIZONTAL

SWITCH
15
230
149
263
show-energy?
show-energy?
0
1
-1000

PLOT
750
15
1020
220
Total Population over Time
Ticks
# of Bees
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count bees"

SLIDER
15
140
187
173
starting-mite-count
starting-mite-count
0
100
100.0
1
1
NIL
HORIZONTAL

PLOT
750
245
1020
430
Number of Sick Bees over Time
Ticks
# of Sick Bees
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count bees with [sick? = true]"

MONITOR
750
455
872
500
% of Bees Sick
(count bees with [sick? = true])/(count bees) * 100
5
1
11

SWITCH
15
275
132
308
add-thyme?
add-thyme?
0
1
-1000

SWITCH
15
320
152
353
add-spearmint?
add-spearmint?
1
1
-1000

INPUTBOX
15
430
125
490
carrying_capacity
200.0
1
0
Number

INPUTBOX
15
365
140
425
time_reapplication
1.0
1
0
Number

PLOT
1040
15
1320
220
plot 1
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plotxy [mite-1] of hive 0 [mite-2] of hive 0"

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

bee
true
4
Polygon -1184463 true true 152 149 77 163 67 195 67 211 74 234 85 252 100 264 116 276 134 286 151 300 167 285 182 278 206 260 220 242 226 218 226 195 222 166
Polygon -16777216 true false 150 149 128 151 114 151 98 145 80 122 80 103 81 83 95 67 117 58 141 54 151 53 177 55 195 66 207 82 211 94 211 116 204 139 189 149 171 152
Polygon -1184463 true true 151 54 119 59 96 60 81 50 78 39 87 25 103 18 115 23 121 13 150 1 180 14 189 23 197 17 210 19 222 30 222 44 212 57 192 58
Polygon -16777216 true false 70 185 74 171 223 172 224 186
Polygon -16777216 true false 67 211 71 226 224 226 225 211 67 211
Polygon -16777216 true false 91 257 106 269 195 269 211 255
Line -1 false 144 100 70 87
Line -1 false 70 87 45 87
Line -1 false 45 86 26 97
Line -1 false 26 96 22 115
Line -1 false 22 115 25 130
Line -1 false 26 131 37 141
Line -1 false 37 141 55 144
Line -1 false 55 143 143 101
Line -1 false 141 100 227 138
Line -1 false 227 138 241 137
Line -1 false 241 137 249 129
Line -1 false 249 129 254 110
Line -1 false 253 108 248 97
Line -1 false 249 95 235 82
Line -1 false 235 82 144 100

bee 2
true
0
Polygon -1184463 true false 195 150 105 150 90 165 90 225 105 270 135 300 165 300 195 270 210 225 210 165 195 150
Rectangle -16777216 true false 90 165 212 185
Polygon -16777216 true false 90 207 90 226 210 226 210 207
Polygon -16777216 true false 103 266 198 266 203 246 96 246
Polygon -6459832 true false 120 150 105 135 105 75 120 60 180 60 195 75 195 135 180 150
Polygon -6459832 true false 150 15 120 30 120 60 180 60 180 30
Circle -16777216 true false 105 30 30
Circle -16777216 true false 165 30 30
Polygon -7500403 true true 120 90 75 105 15 90 30 75 120 75
Polygon -16777216 false false 120 75 30 75 15 90 75 105 120 90
Polygon -7500403 true true 180 75 180 90 225 105 285 90 270 75
Polygon -16777216 false false 180 75 270 75 285 90 225 105 180 90
Polygon -7500403 true true 180 75 180 90 195 105 240 195 270 210 285 210 285 150 255 105
Polygon -16777216 false false 180 75 255 105 285 150 285 210 270 210 240 195 195 105 180 90
Polygon -7500403 true true 120 75 45 105 15 150 15 210 30 210 60 195 105 105 120 90
Polygon -16777216 false false 120 75 45 105 15 150 15 210 30 210 60 195 105 105 120 90
Polygon -16777216 true false 135 300 165 300 180 285 120 285

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
NetLogo 6.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Vary_Thyme_Application" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>count bees with [infested? = true] / count bees</metric>
    <enumeratedValueSet variable="number_of_bees">
      <value value="32"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-energy?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="starting-mite-count">
      <value value="11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_flowers">
      <value value="26"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="carrying_capacity">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_hives">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="add-thyme?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <steppedValueSet variable="time_reapplication" first="1" step="1" last="100"/>
    <enumeratedValueSet variable="add-spearmint?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Vary_Spearmint_Application" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>count bees with [sick? = true] / count bees</metric>
    <enumeratedValueSet variable="number_of_bees">
      <value value="32"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-energy?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="starting-mite-count">
      <value value="11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_flowers">
      <value value="26"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="carrying_capacity">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number_of_hives">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="add-thyme?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <steppedValueSet variable="time_reapplication" first="1" step="1" last="100"/>
    <enumeratedValueSet variable="add-spearmint?">
      <value value="true"/>
      <value value="false"/>
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
1
@#$#@#$#@
