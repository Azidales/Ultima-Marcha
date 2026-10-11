# Última Marcha

Protótipo Android de roguelike de corridas automáticas feito em **Godot 4.5.2**. Projeto versionado neste repositório e compilado no GitHub Actions.

## Versão 0.4 (mecânicas)

- Mapa procedural de 10 etapas, com bifurcações, elites opcionais e chefes obrigatórios.
- Recompensas após vitórias: uma de três cartas em corridas normais, duas de quatro em elites e no primeiro chefe.
- **Peças por espaços** (Turbo, Pneus, Câmbio, Refrigeração, Aerodinâmica e Suspensão). Uma por espaço, mas peças removidas permanecem disponíveis no inventário.
- Cartas **comuns, raras e épicas** com sorteio ponderado; duplicatas não aparecem no mesmo conjunto de recompensas.
- Habilidades passivas **acumuláveis até três vezes por carta**, sem desbloqueios adicionais fora das corridas.
- Sinergias de chassi, turbo refrigerado e transmissão. Pneus de chuva/slick e redução de risco influenciam a simulação.
- Piloto único com XP salvo localmente, especializações e redistribuição gratuita entre tentativas.
- Corridas automáticas com câmera adaptativa e velocidade de reprodução de 1x a 4x.

Os atributos e pesos ainda são parâmetros iniciais, não um balanceamento concluído. Os gráficos continuam provisórios.

## Android

Abra [Actions](https://github.com/Azidales/Ultima-Marcha/actions), escolha um build aprovado e baixe o APK na seção *Artifacts*.

## Testes

O workflow verifica importação GDScript, abertura da cena, mapa, progressão, inventário e cartas, corrida determinística e exportação Android.
