# Navigation Debugger & Checkpoint System

> **Contexto**: Frontend Flutter + Mapbox, backend `/routes` (OTP). Queremos uma forma de **simular navegação** e **guiar o utilizador ponto‑a‑ponto** com base nos `legs` devolvidos pelo OTP, permitindo também um **modo debug** onde a “posição atual” é controlada manualmente (latitude/longitude) em vez do GPS real.

---

## 1. Objectivo Geral

Criar uma camada de **navegação por checkpoints** em cima dos itinerários do OTP, com duas capacidades principais:

1. **Checkpoints fixos ao longo da rota**

   * A rota é estática (vem do OTP).
   * Definimos uma lista de pontos de referência (checkpoints) que o utilizador tem de “alcançar” na ordem certa.
   * À medida que o utilizador se aproxima de cada checkpoint (dentro de um raio X), consideramos esse ponto como concluído e passamos para o próximo.

2. **Modo Debug de Localização**

   * Permite substituir a localização real (Geolocator) por coordenadas inseridas manualmente (lat/lon).
   * Útil para testar navegação sem sair de casa e para reproduzir cenários específicos.
   * A navegação não sabe se a posição vem do GPS ou do debug: apenas reage a uma posição abstrata.

---

## 2. Estrutura de Dados Base (OTP Itinerary)

O backend devolve itinerários no formato OTP enriquecido. Um exemplo simplificado é:

```json
{
  "itineraries": [
    {
      "duration": 16338,
      "walkDistance": 3574.93,
      "startTime": 1764181142000,
      "endTime": 1764197480000,
      "legs": [
        {
          "mode": "WALK",
          "distance": 726.25,
          "from": { "name": "Origin", "lat": 41.1508071, "lon": -8.609899 },
          "to": { "name": "Porto Sao Bento", "lat": 41.1455668, "lon": -8.6102211 },
          "legGeometry": { "points": "..." }
        },
        {
          "mode": "RAIL",
          "distance": 2154.32,
          "from": { "name": "Porto Sao Bento", "lat": 41.1455668, "lon": -8.6102211 },
          "to": { "name": "Porto Campanha", "lat": 41.1487193, "lon": -8.5848353 },
          "legGeometry": { "points": "..." }
        }
      ]
    }
  ]
}
```

Pontos importantes:

* Cada **itinerary** tem uma lista ordenada de **legs**.
* Cada **leg** tem um ponto de origem `from` e de destino `to`, com `lat`/`lon` e `name`.
* `legGeometry.points` contém a polyline codificada da perna (pode ser usada mais tarde para checkpoints mais detalhados).

---

## 3. Conceito de Checkpoints

### 3.1. O que é um checkpoint

Um **checkpoint** é um ponto geográfico (lat/lon) associado a um momento da viagem, que queremos que o utilizador atinja.

Exemplos de checkpoints:

* Fim de cada leg (ex.: chegar à estação "Porto São Bento", depois ao "Porto Campanhã").
* Opcionalmente, pontos intermédios ao longo da polyline (ex.: a cada 100m para navegação mais granular).

### 3.2. Checkpoints mínimos (MVP)

Para o MVP, a abordagem simples é:

* Gerar um checkpoint por cada **destino de leg** (`leg.to`).
* Opcionalmente, guardar também o **primeiro `from`** como referência inicial.

Resultado: se o itinerário tiver 3 legs, teremos 3 checkpoints principais:

1. Fim do leg 1
2. Fim do leg 2
3. Fim do leg 3 (destino final da viagem)

### 3.3. Checkpoints avançados (futuro)

Mais tarde, podemos enriquecer os checkpoints com:

* Amostragem da polyline de cada leg (pontos de forma da linha), para criar pequenos objetivos ao longo do caminho.
* Utilização dos `steps` de WALK (se existirem) para indicar instruções detalhadas de navegação pedonal.

---

## 4. Estado de Navegação

A navegação precisa de manter algum estado mínimo:

1. **Itinerário ativo**

   * O itinerário escolhido pelo utilizador (entre as opções devolvidas pelo backend).

2. **Lista de checkpoints**

   * Derivada do itinerário (por ex.: lista ordenada com todos os `leg.to`).

3. **Índice do checkpoint atual**

   * Inteiro que indica qual é o checkpoint que estamos a tentar atingir neste momento.

4. **Estado de conclusão**

   * Flag para saber se a rota está concluída (quando o último checkpoint é atingido).

5. **Posição atual do utilizador**

   * Lat/lon atual que a lógica de navegação usa (vinda do GPS ou do modo debug).

---

## 5. Lógica de Progresso entre Checkpoints

### 5.1. Input principal: posição atual

A navegação é acionada sempre que a posição do utilizador **muda**. Essa posição pode vir de dois sítios:

* **GPS real** (Geolocator): quando o modo debug está desligado.
* **Modo debug**: quando o developer insere uma lat/lon manualmente.

Em ambos os casos, a função de navegação recebe sempre a **mesma coisa**: uma coordenada atual (lat/lon). A lógica não precisa de saber de onde veio.

### 5.2. Cálculo de distância ao checkpoint

Para cada nova posição:

1. Obter o checkpoint atual (usando o índice atual).
2. Calcular a distância entre a posição do utilizador e a posição do checkpoint.

   * A distância é medida em metros, usando uma fórmula geodésica (ex.: Haversine).

### 5.3. Raio de aceitação (X radius)

Definimos um **raio de aceitação** (em metros) que diz: “se o utilizador estiver a menos de X metros deste checkpoint, consideramos que chegou lá”.

* Para caminhadas (WALK): pode ser algo como **20–30 metros**.
* Para transportes (`RAIL`, `BUS`, `METRO`): o GPS pode ser menos preciso, por isso um raio de **40–60 metros** pode fazer mais sentido.

Este raio pode ser:

* **Global** (um valor fixo para todos os modos, simples para o MVP).
* **Dependente do modo** (valor diferente para WALK, BUS, RAIL, etc.), numa versão mais refinada.

### 5.4. Avançar para o próximo checkpoint

Quando a distância entre a posição do utilizador e o checkpoint atual for **≤ raio definido**:

1. Marcamos o checkpoint atual como concluído.
2. Avançamos o índice para o próximo checkpoint.
3. Se **não há mais checkpoints**:

   * A navegação é marcada como concluída.
   * Podem ser disparadas ações como: mostrar um modal de “Chegaste ao destino”, marcar viagem como `COMPLETED` no histórico, calcular eco score, etc.

Se ainda não chegou ao raio de aceitação:

* Apenas atualizamos a posição atual no estado (para atualizar o mapa, UI, etc.), mantendo o checkpoint atual.

---

## 6. Fonte da Posição: GPS vs Modo Debug

### 6.1. Conceito

A ideia é introduzir um **abstrator de localização** no frontend que:

* Fornece um **stream de posições** (lat/lon) para o sistema de navegação.
* Decide se essa posição vem do **Geolocator** (GPS real) ou do **modo debug**.

Assim, toda a lógica de navegação trabalha sempre com "a posição atual" sem saber se ela é real ou simulada.

### 6.2. Modo normal (GPS)

* O app liga um stream de localização via Geolocator.
* Cada nova posição obtida do GPS é encaminhada para a lógica de navegação como “posição atual”.
* O modo debug está **desligado**.

### 6.3. Modo debug

Quando o utilizador (developer/tester) ativa o modo debug:

1. A fonte de localização **real** deixa de ser usada para avançar a navegação (pode ser ignorada ou pausada).
2. Passa a existir um pequeno painel onde o developer pode:

   * Ativar/desativar o modo debug.
   * Introduzir manualmente valores de `latitude` e `longitude`.
   * Enviar essas coordenadas para a lógica de navegação.

Cada vez que o developer clica em “Aplicar”:

* A posição atual é atualizada para os valores inseridos.
* A lógica de checkpoints é executada exatamente como se a posição fosse real.

### 6.4. Comportamento da UI no modo debug

Um painel típico em cima do mapa pode mostrar:

* **Toggle** `Debug posição: ON/OFF`.
* Campos de texto para `Latitude` e `Longitude`.
* Botão "Aplicar" para enviar a nova posição.
* Informação auxiliar:

  * "Próximo ponto: [nome ou lat/lon]".
  * "Distância até ao próximo ponto: X m".

Assim, o developer consegue:

* Ver a rota desenhada no mapa.
* Ver qual o checkpoint atual.
* Introduzir coordenadas ao longo da rota (por exemplo, copiadas de pontos do OTP ou Mapbox) e observar o sistema a avançar pelos checkpoints.

---

## 7. Comportamento Visual da Navegação

### 7.1. Polylines e marcadores

Enquanto a navegação decorre:

* A **polyline** de todo o itinerário é desenhada no mapa (usando as polylines dos `legs`).
* Podem existir marcadores para:

  * Origem e destino.
  * Estações/terminais principais (ex.: estações de comboio, metro, paragens de autocarro).
  * Opcionalmente, os checkpoints ativos/futuros.

### 7.2. Destacar o checkpoint atual

A interface deve deixar claro **qual é o ponto seguinte** que o utilizador deve atingir. Por exemplo:

* No topo do ecrã: "Segue até Porto São Bento (350 m)".
* No painel de passos: destacar o leg ou passo atual.

### 7.3. Atualização dinâmica com a posição

Sempre que a posição muda:

* O ícone de posição do utilizador move-se no mapa.
* A distância até ao próximo checkpoint é recalculada e mostrada.
* Quando o checkpoint é alcançado (dentro do raio), a UI atualiza para o próximo passo.

### 7.4. Conclusão da rota

Quando o último checkpoint é atingido:

* A rota é marcada como concluída.
* O frontend pode:

  * Mostrar um ecrã/modal de "Chegaste ao destino".
  * Atualizar o histórico (`RouteHistory`) para `COMPLETED`.
  * Disparar cálculo e apresentação do eco score e métricas da viagem.

---

## 8. Extensões Futuras

1. **Checkpoints baseados em polyline**

   * Gerar vários pontos ao longo de cada leg (por exemplo, a cada 50–100 metros) a partir da polyline decodificada.
   * Permitir uma navegação mais precisa e fluida, com confirmação de progresso contínuo.

2. **Raio adaptativo por modo de transporte**

   * Valores diferentes para WALK, BIKE, BUS, METRO, RAIL, etc.
   * Possível ajuste baseado em qualidade de sinal GPS.

3. **Instruções de navegação pedonal detalhadas**

   * Usar os `steps` (quando disponíveis) para mostrar direções do tipo "Vira à direita na Rua X".

4. **Rerouting (recalcular rota)**

   * Se a distância do utilizador à polyline da rota for demasiado grande, podemos considerar que “saiu da rota” e oferecer recalcular.

5. **Integração com preferências do utilizador**

   * Cruzar o sistema de navegação com as preferências guardadas (ex.: evitar certos modos, limites de caminhada, etc.).

---

## 9. Resumo

* A rota vem do backend sob a forma de **itinerários OTP**, com uma lista de `legs` e as respetivas origens/destinos.
* Construímos uma lista ordenada de **checkpoints** (pelo menos um por leg), que representam os pontos que o utilizador deve atingir.
* Mantemos um **estado de navegação** com o checkpoint atual, a posição do utilizador e se a rota já terminou.
* A cada nova posição (GPS real ou debug), calculamos a distância até ao checkpoint atual:

  * Se estiver dentro de um **raio de aceitação**, avançamos para o próximo checkpoint.
  * Se não, apenas atualizamos a posição na UI.
* Um **painel de debug** permite testar toda esta lógica manualmente, introduzindo coordenadas em vez de depender do GPS.

Com isto, temos uma base sólida para navegação assistida + um modo de desenvolvimento extremamente útil para testar rotas e fluxos de UI sem sair de casa.
