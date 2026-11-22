# Mynik — privacidade e termos

O Mynik é uma dashboard pessoal, de uso individual e não comercial. Só o dono
(Domynik) a usa, com as suas próprias contas.

## Dados bancários (open banking)

- A ligação aos bancos é feita pelo [Enable Banking](https://enablebanking.com),
  ao abrigo da PSD2, só com acesso de leitura (saldos e movimentos).
- O consentimento é dado no próprio banco e dura no máximo 180 dias. Pode ser
  retirado a qualquer momento no Mynik (Definições → Bancos → Desligar) ou no banco.
- Os saldos e movimentos ficam na base de dados Supabase do dono, protegida por
  Row Level Security: só a conta dele os lê.
- A chave privada da aplicação fica nos segredos da Edge Function no servidor;
  nunca está no código, no git nem nas apps.
- Nada é partilhado, vendido ou usado para publicidade.

## Termos

Software pessoal, fornecido como está, sem garantias. Não há outros utilizadores
nem serviços pagos.

Contacto: através do repositório [github.com/Domyniik/mynik](https://github.com/Domyniik/mynik).
