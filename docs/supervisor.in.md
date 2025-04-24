# Supervisors em Ract

## Visão Geral

Um Supervisor é um padrão de design para gerenciar processos ou threads concorrentes, originário do ecossistema Erlang/OTP. Sua principal função é monitorar threads/processos filhos e tomar ações quando eles falham, como reiniciá-los seguindo uma estratégia específica.

No Ract, os Supervisors são implementados para fornecer resiliência e auto-recuperação para suas aplicações concorrentes, permitindo que o sistema continue funcionando mesmo quando partes dele falham.

## Principais Conceitos

### Estratégias de Supervisão

Ract suporta diferentes estratégias de supervisão para lidar com falhas:

- **ONE_FOR_ONE**: Quando uma thread filha falha, apenas essa thread específica é reiniciada. As outras threads continuam funcionando normalmente.
- **ONE_FOR_ALL**: Se uma thread falhar, todas as threads filhas são reiniciadas.
- **REST_FOR_ONE**: Se uma thread falhar, essa thread e todas as threads iniciadas após ela são reiniciadas.

### Configuração do Supervisor

Você pode configurar o comportamento do Supervisor globalmente:

```ruby
Ract.configure do |config|
  config.supervisor_strategy = Ract::Supervisor::ONE_FOR_ONE
  config.supervisor_max_restarts = 5  # Máximo de 5 reinicializações
  config.supervisor_max_seconds = 5   # Em um período de 5 segundos
end
```

### Criação de um Supervisor

```ruby
supervisor = Ract.supervisor(
  name: 'Purge data on AWS',
  strategy: Ract::Supervisor::ONE_FOR_ONE
)
```

### Adicionando Threads Filhas

> [!NOTE]
> Cada child deve ser um Ract object.
>

```ruby
promise = Ract { alguma_tarefa() }
supervisor.add_child(promise)
```

### Iniciando o Supervisor

```ruby
supervisor.start!
```

## Limites de Reinicialização

O supervisor controla quantas vezes tenta reiniciar as threads em um determinado período:

- `supervisor_max_restarts`: Número máximo de reinicializações permitidas
- `supervisor_max_seconds`: Período de tempo em que as reinicializações são contadas

Se o número de falhas exceder esses limites, o supervisor geralmente para de tentar reiniciar e propaga o erro para níveis superiores.

## Benefícios do padrão Supervisor

1. **Resiliência**: Falhas em uma thread não derrubam todo o sistema
2. **Auto-recuperação**: Threads que falham são automaticamente reiniciadas
3. **Isolamento**: Problemas são contidos dentro de limites definidos
4. **Monitoramento**: Fornece estatísticas e informações sobre o estado das threads

## Exemplo Completo

```ruby
require 'ract'

# Configuração do Supervisor
Ract.configure do |config|
  config.supervisor_strategy = Ract::Supervisor::ONE_FOR_ONE
  config.supervisor_max_restarts = 5
  config.supervisor_max_seconds = 5
end

# Criação do Supervisor
supervisor = Ract.supervisor(
  name: 'ProcessadorDeTarefas',
  strategy: Ract::Supervisor::ONE_FOR_ONE
)

# Função que pode falhar
def tarefa_com_possivel_falha(id)
  # Lógica da tarefa que pode falhar
  if rand < 0.3
    raise "Falha na tarefa #{id}"
  else
    "Resultado da tarefa #{id}"
  end
end

# Adicionar tarefas ao supervisor
promises = []

5.times do |i|
  promise = Ract { tarefa_com_possivel_falha(i) }
  promises << supervisor.add_child(promise)
end

  # Você pode passsar um block como child

  promises << supervisor.add_child(promise) do
    puts "Tarefa reiniciando...."
  end
end


# Iniciar o supervisor
supervisor.start!

# Verificar resultados
promises.each_with_index do |promise, i|
  puts "Promise #{i}: State=#{promise.state}, " +
       (promise.fulfilled? ? "Value=#{promise.value.inspect}" : "Reason=#{promise.reason.inspect}")
end
```

## Considerações Avançadas

### Estado do Supervisor

Você pode verificar se um supervisor está em execução:

```ruby
supervisor.running?
```

### Estatísticas do Supervisor

Para obter estatísticas sobre o supervisor:

```ruby
supervisor.stats
```

### Comportamento de Reinicialização

Por padrão, o supervisor só reinicia threads filhas quando está em execução. Este comportamento pode ser personalizado modificando a implementação do método `restart_child`.

## Conclusão

O padrão Supervisor é particularmente útil em sistemas que precisam ter alta disponibilidade e tolerância a falhas. Ao implementar supervisores em sua aplicação Ract, você pode criar sistemas mais robustos que se recuperam automaticamente de falhas transitórias e isolam problemas para evitar falhas em cascata.