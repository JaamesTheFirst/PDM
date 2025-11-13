# FUTURE_IMPLEMENTATIONS_MVP

Documento de alinhamento sobre o que precisa de ser implementado no EcoMove para o MVP, focado em:
- fluxos de utilizador,
- lógicas de cálculo de rotas,
- suporte na base de dados,
- métricas ecológicas e histórico.

---

## 1. Objetivo do EcoMove

Dar ao utilizador formas inteligentes e ecológicas de ir **do ponto A ao ponto B**, comparando diferentes modos de transporte, mostrando:
- rota,
- tempo,
- custo (se possível),
- impacto ambiental (CO₂, etc.),
- passos intermédios necessários (ex: ir até uma paragem, dock de bicicletas, estação, etc.).

---

## 2. Fluxo base do utilizador

### 2.1. Seleção de origem e destino

- [ ] Ecrã/mapa onde o utilizador escolhe:
  - **De**: localização atual ou endereço/ponto de interesse.
  - **Para**: endereço/ponto de interesse.
- [ ] Suporte a:
  - Selecionar no mapa.
  - Pesquisar por nome de rua ou POI (via API de geocoding/search, ex: Mapbox Search Box).
- [ ] Guardar as pesquisas em histórico (ver secção de BD).

### 2.2. Listagem de modos de transporte possíveis

Para um par (origem, destino), o app deve listar **modos possíveis** (mesmo que alguns sejam só “placeholder” no MVP):

- Caminhada  
- Bicicleta (própria)  
- Bike-share  
- Trotinete elétrica (própria)  
- Trotinete-share  
- Autocarro  
- Comboio (se houver APIs / dados)  
- Carro (combustível)  
- Táxi / TVDE  
- Carro elétrico  

Requisitos:

- [ ] A **ordem** dos modos neste momento não é crítica, pode ser fixa ou por tipo (eco-friendly vs. rápidos vs. convenientes).
- [ ] Cada modo apresenta um **resumo**:
  - Tempo estimado de viagem
  - Distância total
  - Estimativa de CO₂ (ex: “+X kg CO₂” ou “–Y % vs. carro”)
  - Custo estimado (se houver dados, mesmo aproximados)
- [ ] Possível separação visual por categoria:
  - “Mais ecológicos” (caminhada, bicicleta, bike-share, trotinete, etc.)
  - “Transporte público” (autocarro, comboio)
  - “Individual motorizado” (carro, táxi, elétrico)

---

## 3. Lógica de rotas por modo

### 3.1. Modos diretos (sem passos intermédios complexos)

Modos que vão **diretamente** de origem ao destino, com uma rota simples:

- Caminhada  
- Bicicleta  
- Trotinete elétrica  
- Carro  
- Táxi  
- Carro elétrico  

Para estes:

- [ ] Usar API de direções (ex: Mapbox Directions) com `profile` adequado:
  - `walking` → Caminhada
  - `cycling` → Bicicleta / Trotinete (se fizer sentido)
  - `driving` → Carro / Táxi / Elétrico
- [ ] Guardar:
  - Distância total
  - Tempo estimado
  - Polyline / coordenadas da rota
- [ ] Calcular CO₂ com base no modo (ver secção 6).

### 3.2. Modos com ponto intermédio (multimodais simples)

Modos onde o utilizador precisa **ir a um ponto primeiro**, e depois continua até ao destino:

- Bike-share  
- Trotinete-share  
- Autocarro  
- Comboio (se houver)

#### 3.2.1. Bike-share e Trotinete-share

Fluxo típico:
1. Rota **a pé** da origem → estação/dock/veículo mais próximo disponível.
2. Rota de **bike/trotinete** → dock próximo do destino.
3. (Opcional) Pequeno trecho final **a pé** dock → destino.

Requisitos:

- [ ] API/serviço que dê:
  - Lista de estações / veículos disponíveis (com coordenadas e disponibilidade).
- [ ] Lógica para:
  - Encontrar estação inicial “ótima” perto da origem.
  - Encontrar estação final “ótima” perto do destino.
- [ ] Construir rota em segmentos:
  - Segmento 1 (walking)
  - Segmento 2 (cycling/scooter)
  - Segmento 3 (walking)
- [ ] Calcular tempo & CO₂ por segmento e totalizar.

#### 3.2.2. Autocarro

Fluxo típico:
1. Caminhar da origem → paragem de autocarro adequada.
2. Esperar autocarro (considerar horário).
3. Autocarro percorre parte maior da rota.
4. Caminhar da paragem final → destino.

Requisitos:

- [ ] Acesso a dados:
  - Paragens de autocarro (coordenadas).
  - Linhas e percursos básicos (mesmo estáticos).
  - Horários / frequências (idealmente).
- [ ] Lógica:
  - Escolher paragem inicial e final relevantes (com base na linha que aproxima o destino).
  - Estimar:
    - **Tempo de espera** (em função do horário).
    - Tempo de percurso dentro do autocarro.
  - Rota segmentada:
    - Origem → paragem inicial (walking)
    - Trajeto autocarro (polyline da linha ou aproximação)
    - Paragem final → destino (walking)
- [ ] Mostrar **disponibilidade** / informação útil:
  - Hora do próximo autocarro.
  - Frequência (ex: “a cada 15 min”).
  - Linhas que passam nas paragens usadas.

#### 3.2.3. Comboio (se possível)

Semelhante ao autocarro, mas com:

- Estações em vez de paragens.
- Horários mais rígidos.
- Possível integração futura com dados reais (GTFS / APIs externas).

MVP básico:

- [ ] Mesmo modelo de 3 etapas:
  - Caminhada → estação
  - Segmento comboio
  - Caminhada → destino
- [ ] Pode começar com dados estáticos simplificados.

---

## 4. Acompanhamento da rota em tempo real

Depois de o utilizador escolher uma rota/modo:

- [ ] Ecrã de **navegação** por modo:
  - Mostrar posição atual do utilizador no mapa.
  - Destacar a polyline da rota ativa.
  - Mostrar instruções básicas (nem que seja “seguir linha no mapa” no MVP).
- [ ] Acompanhamento por **segmentos**:
  - Ex: no autocarro:
    - Segmento 1: “Ir a pé até à paragem X”.
    - Segmento 2: “Apanhar autocarro da linha Y”.
    - Segmento 3: “Sair na paragem Z e ir a pé até ao destino”.
- [ ] Lógica de “estado” da viagem:
  - Em andamento
  - Em pausa (se o user sair da rota)
  - Concluída

Quando o utilizador **chega ao destino**:

- [ ] Marcar rota como concluída.
- [ ] Guardar no histórico (rota, modo, tempo real, CO₂ estimado).
- [ ] Possível micro-interação (ex: mostrar CO₂ poupado).

---

## 5. Suporte na Base de Dados

Precisamos adaptar a BD para suportar:

### 5.1. Histórico de rotas

- [ ] Tabela: `routes_history`
  - `id`
  - `user_id`
  - `origin` (coords + texto formatado)
  - `destination` (coords + texto)
  - `mode` (ou modos, se multimodal)
  - `distance_meters`
  - `duration_seconds`
  - `co2_kg`
  - `started_at`
  - `finished_at`
  - `segments` (JSON com detalhes por segmento: tipo, distância, etc.)

### 5.2. Histórico de POIs / ruas pesquisadas

- [ ] Tabela: `search_history`
  - `id`
  - `user_id`
  - `query`
  - `place_id` (se vier de API tipo Mapbox)
  - `place_name` (string formatada para mostrar depois)
  - `coords` (lat/lng)
  - `searched_at`

### 5.3. Estatísticas ecológicas e gerais

- [ ] Tabela: `eco_stats_aggregate` (por utilizador, talvez por dia/semana/mês)
  - `user_id`
  - `period` (ex: `2025-11` ou `2025-11-13`)
  - `total_distance_meters`
  - `total_duration_seconds`
  - `total_co2_kg`
  - `co2_saved_vs_car_kg` (comparação vs. usar carro para todas as rotas)
- [ ] Tabela para gamificação futura (badges, achievements) – pode ficar **pós-MVP**, mas já pensar estrutura.

### 5.4. Dados de infraestrutura (se armazenados localmente)

Se não ficarmos 100% dependentes de APIs externas:

- [ ] `transit_stops` (paragens de autocarro, comboio)
- [ ] `transit_lines`
- [ ] `bike_share_stations`
- [ ] `scooter_share_zones/stations`

MVP pode começar só com leitura de APIs externas, mas o modelo de BD deve prever guardar:

- ID externo (da API)
- Coordenadas
- Nome
- Tipo
- Informação mínima de disponibilidade ou horário (se ficheiros estáticos).

---

## 6. Cálculo de CO₂ por modo

Precisamos de um **modelo simples** mas coerente para estimar:

- [ ] Caminhada / Bicicleta / Trotinete (própria) → **0 emissões diretas** (podemos considerar “0 kg CO₂”).
- [ ] Bike-share / Trotinete-share → tratar como muito baixo, pode usar valor constante por km (ex: produção/manutenção).
- [ ] Autocarro / Comboio → fator de emissão por passageiro por km (valor aproximado).
- [ ] Carro (combustível) → fator de emissão por km (padrão médio, ex: ~0.15–0.2 kg/km, a ajustares).
- [ ] Táxi → semelhante a carro, talvez com fator ligeiramente maior se fizer sentido.
- [ ] Carro elétrico → fator reduzido por km (dependendo da origem da eletricidade; para já valor fixo simplificado).

BD / lógica:

- [ ] Tabela/constante `emission_factors`:
  - `mode`
  - `kg_co2_per_km`
- [ ] Função:
  - Input: modo + distância em metros
  - Output: `co2_kg = factor * (distance_m / 1000)`

Também:

- [ ] Cálculo de **CO₂ evitado** vs. cenário “usar carro”:
  - `co2_saved = co2_if_car - co2_actual`
- [ ] Guardar estes valores por rota no histórico.

---

## 7. Estatísticas e dashboards básicos

Para dar feedback ao utilizador:

- [ ] Ecrã de estatísticas:
  - Total de km percorridos (por modo).
  - CO₂ total emitido.
  - CO₂ total poupado vs. carro.
  - Número de viagens concluídas.
- [ ] Possível vista semanal/mensal:
  - “Esta semana poupaste X kg de CO₂.”
- [ ] Baseado em `routes_history` + `eco_stats_aggregate`.

---

## 8. Considerações de MVP vs. Pós-MVP

### 8.1. MVP (obrigatório)

- Seleção de origem/destino (mapa + pesquisa).
- Listagem de modos com:
  - Tempo estimado
  - Distância
  - CO₂ estimado
- Rotas diretas (caminhada, bicicleta, carro, etc.) via API de direções.
- Pelo menos **uma** implementação simples de modo multimodal:
  - Ex: autocarro com paragens e pseudo-horários, ou bike-share com estações fixas.
- Acompanhamento básico da rota (seguir polyline no mapa).
- Histórico de rotas.
- Histórico de pesquisas.
- Cálculo básico de CO₂.
- Ecrã simples de estatísticas (total de CO₂ poupado, etc.).

### 8.2. Pós-MVP (nice to have / evolução)

- Dados de autocarro/combóio em tempo real (GTFS-RT ou APIs).
- Disponibilidade em tempo real de bike-share / trotinete-share.
- Melhor UI de navegação com instruções “turn-by-turn”.
- Gamificação mais avançada (badges, níveis, desafios).
- Perfis de utilizador com preferências (ex: evitar subidas, evitar chuva se ligado ao tempo).
- Roteamento mais inteligente (combinações mais complexas: ex: autocarro + comboio + caminhada).

---

## 9. Resumo

Para o MVP do EcoMove precisamos de:

- Um **fluxo sólido de origem → destino**.
- Suporte a **vários modos de transporte**, incluindo multimodais simples (ir até um ponto primeiro).
- Uma **base de dados preparada** para histórico de rotas, pesquisas e métricas ecológicas.
- Cálculo de **CO₂ por modo e por viagem**, com comparação vs. carro.
- Lógica de **acompanhamento da rota** até ao destino e marcação de conclusão.

Tudo isto deve ser implementado de forma modular, para facilitar:
- troca de APIs de mapas/transporte,
- extensão para mais modos,
- e adição de camadas mais “smart” no futuro.
