globals [

  attendance
  history
  home-patches
  crowded-patch

  ;;Acumulado de personas satisfechas y no satisfechas en función del tiempo
  acumulado-satisfactorio
  acumulado-no-satisfactorio

  ;;Este es el tick donde inicia la pandemia
  ;;tiempo-inicio-epidemia

  ;;Numero de eventos no satisfactorio y satisfactorios
  ;; Satisfactorio + No_Satisfactorios = N ticks
  eventos-satisfactorios
  eventos-no-satisfactorios

  cumulative-attendance
  average-attendance

  pts
  attendances

  ;; Número de individuos
  n-individuos

  ;; Número de agentes permitidos
  capacidad-max

  ;; Representa la superficie del supermercado en azul
  super-patches

  aforo-actual

  infectados-pico
  pico-tiempo

  lista-asistencia
  asistencia-max-ip ;;desde-inicio-pandemia
  asistencia-min-ip ;;desde-inicio-pandemia

  conteo-sanos
  conteo-infectados
  conteo-recuperados

]

turtles-own [
  strategies
  best-strategy
  attend?
  prediction
  n-attends
  mean-attends-time

  sano?
  infectado?
  recuperado?

  tiempo-enfermedad-int
  x-casa
  y-casa
]


to setup
  clear-all

  set n-individuos poblacion-total
  set attendances [ ]

  set-default-shape turtles "person"

  ;; creamos la casas
  set home-patches patches with [pycor < 0 or (pxcor <  0 and pycor >= 0)]
  ask home-patches [ set pcolor 37 ]

  ;; creamos el tamaño del supermercado
  set super-patches patches with [pxcor > 0 and pycor > 0]
  ask super-patches [ set pcolor 7 ]
  ;;show (word "parches-azules" count super-patches)

  ;; Capacidad maxima del supermercado segun los parches del super.
  set capacidad-max count super-patches

  ;; el aforo en porcentaje
  set aforo-actual floor ( ( count super-patches ) * 0.01 * aforo )

  ;; el aforo actual para el bar el farol es lo mismo que arriba.
  set umbral aforo-actual

  set infectados-pico 0
  set pico-tiempo 0

  set lista-asistencia []
  set asistencia-max-ip 0
  set asistencia-min-ip 0

  ;;Inicializamos el conteo de personas satisfechas o no-satisfechas
  set acumulado-satisfactorio 0
  set acumulado-no-satisfactorio 0

  ;;Inicialización del conteo de eventos
  set eventos-satisfactorios 0
  set eventos-no-satisfactorios 0

  ;;Conteo de agentes
  set conteo-sanos 0
  set conteo-infectados 0
  set conteo-recuperados 0

  ;; initialize the previous attendance randomly so the agents have a history
  ;; to work with from the start.
  ;; la historia es el doble de la memoria, porque necesitamos al menos una memoria valida de historia
  ;; para cada punto de la memoria para probar, para decir qué tan bien habrían funcionado las estrategias
  set history n-values (tamano-memoria * 2) [random count super-patches] ;;antes tenia 100 por que era el maximo

  ;;Del arreglo de historia la "asistencia actual" el el first del arreglo
  set attendance first history

  set cumulative-attendance 0

  ;; use one of the patch labels to visually indicate whether or not the
  ;; bar is "crowded"
  ask patch (0.75 * max-pxcor) (0.5 * max-pycor) [
    set crowded-patch self
    set plabel-color red
  ]

  ;; create the agents and give them random strategies
  ;; these are the only strategies these agents will ever have though they
  ;; can change which of this "bag of strategies" they use every tick
  create-turtles n-individuos [

    set color blue
    ;; la inicialización del modeo lo SIR, todos empiezan sanos
    set sano? true ;; sano true
    set infectado? false ;;infectado false
    set recuperado? false ;;infectado false

    ;; Los posicionamos en el espacio de manera aleatoria, buscando un parche-casa vacio y estableciendolo para toda la ejecución
    set-lugar-residencia home-patches

    ;;Creamos nuestro vector de vectores de estrategias, por  [ S1[m1,m2,m3,...,mn], S2[m1,m2,m3,...,mn], ..., Sn[m1,m2,m3,...,mn] ]
    set strategies n-values numero-estrategias [random-strategy]

    ;;show (word who " " strategies)

    ;;La mejor estrategia es la primera de la lista.
    set best-strategy first strategies

    set n-attends 0
    set mean-attends-time 0

    update-strategies

  ]


  ask turtle 1 [
    set label who
    set label-color black
    ;;show (word "prediccion tortuga 4 " prediction )
  ]


  ;; start the clock
  reset-ticks
end


to go

  if ( tiempo-inicio-epidemia  = ticks)
  [
    ;;Mecanismo inicial de contagio
    ask turtles [
      if(  random 100 < porcentaje-enfermos )
      [
        set color red
        set sano? false ;; sano true
        set infectado? true ;;infectado false
        set recuperado? false ;;infectado false

        ;;se inicializa el tiempo de enfermedad
        set tiempo-enfermedad-int floor random-normal tiempo-enfermedad 10
      ]
   ]
  ]


  ;;set umbral capacidad_super * aforo;

  ;; update the global variables
  ask crowded-patch [ set plabel "" ]


  ;; each agent predicts attendance at the bar and decides whether or not to go
  ;; primero se pregunta si tienen que ir o no, pero el mecanismo está arriba o abajo de estar
  ;; enfermos?
  ask turtles [

    ;;to-report predict-attendance [strategy subhistory]
    ;; Esta instanciando con la mejor estrategia y la historia, función de la forma: sublist list position1 position2
    set prediction predict-attendance ( best-strategy ) ( sublist history 0 tamano-memoria )
    set attend? (prediction <= umbral)  ;; true or false

  ]


  ;; depending on their decision, the agents go to the bar or stay at home
  ask turtles [

    ;;si esta infectado y ES responsable entonces cambia de parecer.
    if( infectado? and random-float 100 < cuarentena )
    [
      set attend? false
    ]


    ;;Asiste al supermercado
    ifelse attend?
    [

      ;; si puedo entrar el agente
      ifelse ( ir-al-super-si-es-posible super-patches 10 )[

        ;;move-to-empty-one-of super-patches
        set attendance attendance + 1

        set n-attends n-attends + 1
        set mean-attends-time n-attends / ( ticks + 1 )

        ;;si esta infectado, entonces, contagia!
        if( infectado? )
        [
          ;;contagia a los que están en su entorno con una probabilidad (parámetro)
          mecanismo-infeccion
        ]

        ;;Fui, entre y pude contagiar o no todo lo que quice; normalmente,
        ;;update-strategies

      ]
      [

        regresar-a-casa
        ;;quice entrar y no pude enfermo o no, meter -1 a la estrategia
        ;;update-strategies -1
      ]
    ]
    [
      regresar-a-casa
      ;;move-to-empty-one-of home-patches

      ;;update-strategies_enfermo  -> no se que esta pasando entonces le pongo cero,
      ;;update-strategies 0

    ]

    ;;Ya asistio o no asistio, pero sigue la dinámica de la enfermedad, decrementar el tiempo de enfermedad.
    if ( infectado? )
    [

      ifelse ( tiempo-enfermedad-int = 0 )
      [
        set color green
        set sano? false
        set infectado? false
        set recuperado? true
      ]
      [
        set tiempo-enfermedad-int tiempo-enfermedad-int - 1
      ]
    ]
  ]

  ;; if the supermarket is crowded indicate that in the view
  set attendance count turtles-on super-patches

  ifelse attendance > umbral [
    ask crowded-patch [ set plabel "Sobrepasa" ]
    set acumulado-no-satisfactorio acumulado-no-satisfactorio + attendance
    ;;Conteo de un evento no satisfactorio
    set eventos-no-satisfactorios eventos-no-satisfactorios + 1
  ]
  [
    set acumulado-satisfactorio acumulado-satisfactorio + attendance
    ;;Conteo de un evento satisfactorio
    set eventos-satisfactorios eventos-satisfactorios + 1
  ]

  ;; update the attendance history
  ;;fput item list : Adds item to the beginning of a list and reports the new list.
  ;; remove oldest attendance and prepend latest attendance
  ;; actualizamos el arreglo de historia, quitamos el ultimo elemento con but-last y ponemos en la primera posición con fput la asistencia actual al supermercado.
  set history fput attendance but-last history


  ;;-----------------------------------------------------------------
  ;; La parte mas imporante actualiza su estrategia.
  ask turtles [ update-strategies ]
  ;;------------------------------------------------------------------

  set cumulative-attendance cumulative-attendance + attendance

  if ( infectados-pico < count turtles with [ infectado?] )[
    set infectados-pico count turtles with [ infectado?]
    set pico-tiempo ticks
  ]

  if (ticks > tiempo-inicio-epidemia )[
    set lista-asistencia fput attendance lista-asistencia

    set asistencia-min-ip min lista-asistencia
    set asistencia-max-ip max lista-asistencia
  ]

  set conteo-sanos count turtles with [ sano? ]
  set conteo-infectados count turtles with [ infectado? ]
  set conteo-recuperados count turtles with [ recuperado? ]


  ;; ordering the plot ask turtles [ plotxy who mean-attends-time]
  Order

  ;; feeding the attendances list
  set attendances insert-item 0 attendances attendance

  ;; updates de average attendance
  if( ticks > 0)[set average-attendance cumulative-attendance / ticks]

  ;; advance the clock
  tick
end

to Order
  set pts sort [mean-attends-time] of turtles
end

to plotByOrder
  ;clear-plot
  set pts sort [mean-attends-time] of turtles
  ;;foreach pts [[pt] -> plot pt]
end


;; determina qué estrategia habría predicho los mejores resultados si se hubiera utilizado en esta ronda.
;; La mejor estrategia es la que tiene la suma de las diferencias más pequeñas entre las
;; asistencia actual y la asistencia prevista para cada uno de los
;; semanas (volviendo semanas tamano-memoria)
;; esto no cambia las estrategias en absoluto, pero sí (potencialmente) cambia la
;; actualmente en uso y actualiza el rendimiento de todas las estrategias
to update-strategies

  ;; initialize best-score to a maximum, which is the lowest possible score; antes era 100, la capacidad máxima del bar
  let best-score tamano-memoria * ( count super-patches ) + 1 ;;;(1,1,1, ... 1)

  ;;Va variando las estretegias
  ;;Un ciclo doble, sobre estrategias y sobre componentes de cada estrategia (segun tamaño de memoria)
  foreach strategies [ the-strategy ->
    let score 0
    let week 1

    repeat tamano-memoria [
      ;;predict-attendance [strategy subhistory], es decir, recibe la estrategia (toda) y una sublista, la historia desde 1 hasta el tamaño de la memoria.

                                                            ;;una sublista del tamaño de la memoria
      set prediction predict-attendance  ( the-strategy ) ( sublist history week (week + tamano-memoria) ) ;;sublist list position1 position2
      ;;show ( word who " mi-prediccion: " prediction )
      set score score + abs (item (week - 1) history - prediction)
      set week week + 1
    ]

    if (score <= best-score) [
      set best-score score
      set best-strategy the-strategy
    ]
  ]

end


;; This reports an agent's prediction of the current attendance
;; using a particular strategy and portion of the attendance history.
;; More specifically, the strategy is then described by the formula
;; p(t) = x(t - 1) * a(t - 1) + x(t - 2) * a(t -2) + ... + x(t - tamano-memoria) * a(t - tamano-memoria) + c * 100,
;; where p(t) is the prediction at time t, x(t) is the attendance of the bar at time t,
;; a(t) is the weight for time t, c is a constant, and tamano-memoria is an external parameter.
to-report predict-attendance [strategy subhistory]
  ;; the first element of the strategy is the constant, c, in the prediction formula.
  ;; one can think of it as the the agent's prediction of the bar's attendance
  ;; in the absence of any other data
  ;; then we multiply each week in the history by its respective weight
  report (count super-patches ) * first strategy + sum (map [ [weight week] -> weight * week ] ( butfirst strategy ) subhistory)
  ;;map reporter list, donde reporter es [ [weight week] -> weight * week ] y list es butfirst strategy subhistory ; butfirst
end

;; Reporta una estrategia aleatoria. Una estrategia es un conjunto de pesos de -1.0 a 1.0 que
;; determina cuánto énfasis se pone en cada período de tiempo anterior al hacer
;; una predicción de asistencia para el próximo período de tiempo
to-report random-strategy
  ;;Regresa un un vector de tamaño memoria más 1, donde cada entrada, esta entre -1 y 1, de manera aleatoria,
  report n-values (tamano-memoria + 1) [1.0 - random-float 2.0]

  ;; Por ejemplo:
  ;; [-0.5111908964720122 0.6260919749724325 0.9496380169981626 0.4811513211924301 -0.8567881389293679 0.5412322134974361]
end


;; In this model it doesn't really matter exactly which patch
;; a turtle is on, only whether the turtle is in the home area
;; or the bar area.  Nonetheless, to make a nice visualization
;; this procedure is used to ensure that we only have one
;; turtle per patch.
;to move-to-empty-one-of [locations]  ;; turtle procedure
;  move-to one-of locations
;  while [any? other turtles-here] [
;    move-to one-of locations
;  ]
;
;end

to regresar-a-casa

  setxy x-casa y-casa

end


;; In this model it doesn't really matter exactly which patch
;; a turtle is on, only whether the turtle is in the home area
;; or the bar area.  Nonetheless, to make a nice visualization
;; this procedure is used to ensure that we only have one
;; turtle per patch.
to set-lugar-residencia [locations]  ;; turtle procedure
  move-to one-of locations
  while [any? other turtles-here] [
    move-to one-of locations
  ]

  let mix 0
  let miy 0
  ask patch-here [
    set mix pxcor
    set miy pycor
  ]

  set x-casa mix
  set y-casa miy

end

to-report ir-al-super-si-es-posible [locations intentos]  ;; turtle procedure

  move-to one-of locations
  let intentos-int intentos

  while [any? other turtles-here and intentos-int > 0]
  [
    move-to one-of locations
    set intentos-int intentos-int - 1

    ;;show (word "persona:" who " intentos " intentos-int )
  ]

  ifelse ( intentos-int = 0 ) [
    ;;show(word "se reporta falso")
    report false
  ]
  [
    ;;show(word "se reporta verdadero, se quedo en el super")
    report true
  ]
end


to mecanismo-infeccion

  let nearby-uninfected (turtles-on neighbors) with [ sano? ]

     if nearby-uninfected != nobody
     [ ask nearby-uninfected
       [ if random-float 100 < probabilidad-contagio
         [
           set color red

           set sano? false
           set infectado? true
           set recuperado? false
           set tiempo-enfermedad-int tiempo-enfermedad
         ]
       ]
     ]
end



;to mecanismo-recuperacion
;  set infection-length infection-length + 1
;
;  ;; If people have been infected for more than the recovery-time
;  ;; then there is a chance for recovery
;  if infection-length > recovery-time
;  [
;    if random-float 100 < recovery-chance
;    [ set infectado false
;      set recuperado true
;      set sano false
;      set nb-recovered (nb-recovered + 1)
;    ]
;  ]
;end
@#$#@#$#@
GRAPHICS-WINDOW
215
10
773
569
-1
-1
15.7143
1
24
1
1
1
0
1
1
1
-17
17
-17
17
1
1
1
ticks
30.0

BUTTON
155
10
210
43
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
20
10
80
43
setup
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
20
330
205
363
tamano-memoria
tamano-memoria
1
30
5.0
1
1
NIL
HORIZONTAL

SLIDER
20
365
205
398
numero-estrategias
numero-estrategias
1
30
10.0
1
1
NIL
HORIZONTAL

PLOT
925
10
1575
325
Asistencia al Supermercado
tiempo
asistencia
0.0
10.0
0.0
100.0
true
true
"" ""
PENS
"asistencia" 1.0 0 -16777216 true "" "plot attendance"
"aforo" 1.0 0 -2674135 true "" ";; plot a threshold line -- an attendance level above this line makes the bar\n;; is unappealing, but below this line is appealing\nplot-pen-reset\nplotxy 0 umbral\nplotxy plot-x-max umbral"
"asistencia-promedio" 1.0 0 -13840069 true "" "plot average-attendance"

SLIDER
20
295
205
328
umbral
umbral
0
capacidad-max
86.0
1
1
NIL
HORIZONTAL

MONITOR
1635
25
1725
70
Media
mean [mean-attends-time] of turtles
4
1
11

MONITOR
1635
70
1725
115
Varianza
variance [mean-attends-time] of turtles
3
1
11

MONITOR
780
100
925
145
asistencia-promedio
average-attendance
2
1
11

PLOT
1575
125
1920
320
Histograma de asistencia 
NIL
NIL
0.0
300.0
0.0
100.0
true
false
"" ""
PENS
"default" 1.0 1 -7858858 true "set-histogram-num-bars 100" "histogram attendances"

BUTTON
80
10
157
43
go-once
go
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
20
470
205
503
porcentaje-enfermos
porcentaje-enfermos
0
100
10.0
1
1
%
HORIZONTAL

SLIDER
20
505
205
538
tiempo-enfermedad
tiempo-enfermedad
0
100
40.0
1
1
NIL
HORIZONTAL

SLIDER
20
540
205
573
probabilidad-contagio
probabilidad-contagio
0
100
30.0
1
1
%
HORIZONTAL

TEXTBOX
590
276
745
311
Supermercado
18
9.9
1

SLIDER
20
225
205
258
aforo
aforo
0
100
30.0
1
1
%
HORIZONTAL

TEXTBOX
25
270
175
288
Parámetros \"El Farol\"
15
0.0
1

TEXTBOX
25
415
175
435
Parámetros \"Epidemia\"
15
0.0
1

MONITOR
20
175
110
220
Capacidad Max
count super-patches
17
1
11

SLIDER
20
55
205
88
poblacion-total
poblacion-total
50
900
500.0
1
1
NIL
HORIZONTAL

TEXTBOX
20
145
255
181
Parámetros \"Supermercado\"
15
0.0
1

MONITOR
115
175
205
220
aforo-permitido
floor ( (count super-patches) * 0.01 * aforo )
0
1
11

SLIDER
20
90
205
123
cuarentena
cuarentena
0
100
80.0
1
1
%
HORIZONTAL

PLOT
925
340
1540
565
Población
tiempo
personas
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"sanos" 1.0 0 -13791810 true "" "plot count turtles with [ sano? ]"
"infectados" 1.0 0 -2674135 true "" "plot count turtles with [ infectado? ]"
"recuperados" 1.0 0 -13840069 true "" "plot count turtles with [ recuperado? ]"

MONITOR
780
55
925
100
asistencia
attendance
17
1
11

MONITOR
780
475
925
520
infectados-pico
infectados-pico
17
1
11

MONITOR
780
235
922
280
asistencia-min (fluc)
asistencia-min-ip
17
1
11

MONITOR
780
280
922
325
asistencia-max (fluc)
asistencia-max-ip
17
1
11

MONITOR
780
145
925
190
eventos-satisfactorios
eventos-satisfactorios
17
1
11

MONITOR
780
190
925
235
eventos-no-satisfactorios
eventos-no-satisfactorios
17
1
11

MONITOR
780
10
925
55
aforo-permitido
floor ( (count super-patches) * 0.01 * aforo )
17
1
11

MONITOR
780
340
925
385
sanos
conteo-sanos
17
1
11

MONITOR
780
385
925
430
infectados
conteo-infectados
17
1
11

MONITOR
780
430
925
475
recuperados
conteo-recuperados
17
1
11

SLIDER
20
435
205
468
tiempo-inicio-epidemia
tiempo-inicio-epidemia
1
200
100.0
1
1
NIL
HORIZONTAL

MONITOR
780
520
925
565
pico-tiempo
pico-tiempo
17
1
11

@#$#@#$#@
## COMO FUNCIONA EL MODELO
Referirse al artículo "Dinámicas de asistencia al supermercado “El Farolito” en condiciones de pandemia"


## HOW TO CITE

This model is part of the textbook, “Introduction to Agent-Based Modeling: Modeling Natural, Social and Engineered Complex Systems with NetLogo.”

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Rand, W., Wilensky, U. (2007).  NetLogo El Farol model.  http://ccl.northwestern.edu/netlogo/models/ElFarol.  Center for Connected Learning and Computer-Based Modeling, Northwestern Institute on Complex Systems, Northwestern University, Evanston, IL.

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Please cite the textbook as:

* Wilensky, U. & Rand, W. (2015). Introduction to Agent-Based Modeling: Modeling Natural, Social and Engineered Complex Systems with NetLogo. Cambridge, MA. MIT Press.

## COPYRIGHT AND LICENSE

Copyright 2007 Uri Wilensky.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Uri Wilensky at uri@northwestern.edu.

<!-- 2007 Cite: Rand, W., Wilensky, U. -->
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
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment-con-Resp-10-aforo-86" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>average-attendance</metric>
    <metric>asistencia-min-800</metric>
    <metric>asistencia-max-800</metric>
    <metric>infectados-pico</metric>
    <steppedValueSet variable="numero-estrategias" first="1" step="1" last="20"/>
    <steppedValueSet variable="tamano-memoria" first="1" step="1" last="20"/>
  </experiment>
  <experiment name="experiment-con-Resp-30-aforo-86" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>average-attendance</metric>
    <metric>asistencia-min-800</metric>
    <metric>asistencia-max-800</metric>
    <metric>infectados-pico</metric>
    <steppedValueSet variable="numero-estrategias" first="1" step="1" last="20"/>
    <steppedValueSet variable="tamano-memoria" first="1" step="1" last="20"/>
  </experiment>
  <experiment name="experiment-con-Resp-70-aforo-86" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>average-attendance</metric>
    <metric>asistencia-min-800</metric>
    <metric>asistencia-max-800</metric>
    <metric>infectados-pico</metric>
    <steppedValueSet variable="numero-estrategias" first="1" step="1" last="20"/>
    <steppedValueSet variable="tamano-memoria" first="1" step="1" last="20"/>
  </experiment>
  <experiment name="experiment-con-Resp-90-aforo-86" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>average-attendance</metric>
    <metric>asistencia-min-800</metric>
    <metric>asistencia-max-800</metric>
    <metric>infectados-pico</metric>
    <metric>responsabilidad</metric>
    <steppedValueSet variable="numero-estrategias" first="1" step="1" last="20"/>
    <steppedValueSet variable="tamano-memoria" first="1" step="1" last="20"/>
  </experiment>
  <experiment name="experiment-MEM-EST" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="300"/>
    <metric>average-attendance</metric>
    <metric>eventos-satisfactorios</metric>
    <metric>eventos-no-satisfactorios</metric>
    <metric>asistencia-min-ip</metric>
    <metric>asistencia-max-ip</metric>
    <metric>conteo-sanos</metric>
    <metric>conteo-infectados</metric>
    <metric>conteo-recuperados</metric>
    <metric>infectados-pico</metric>
    <metric>pico-tiempo</metric>
    <steppedValueSet variable="responsabilidad" first="70" step="10" last="100"/>
    <steppedValueSet variable="tamano-memoria" first="1" step="1" last="20"/>
    <steppedValueSet variable="numero-estrategias" first="1" step="1" last="20"/>
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
