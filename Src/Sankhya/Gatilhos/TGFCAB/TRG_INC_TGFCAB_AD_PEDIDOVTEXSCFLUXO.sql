USE [SANKHYA_PRODUCAO]
GO
/****** Object:  Trigger [sankhya].[TRG_INC_TGFCAB_AD_PEDIDOVTEXSCFLUXO]    Script Date: 13/09/2018 17:48:18 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*	=============================================
	Author:			Guilherme Branco Stracini
	Create date:	2014-02-25
	Description:	Realiza o cadastro dos Fluxos dos Pedidos (Expedição, NF-e + Transporte, Transporte, Devolvido)
					para os pedidos do Smart Checkout. Nos caso de transporte e NF-e também atualiza a tela Smart Checkout com o SRO e a Chave NF-e

	Author:			Rafael Turra Silva
	Change date:	2017-03-22
	Description:	Adicionado validação para tops 511 e 520.

	Author:			Guilherme Branco Stracini
	Change date:	2017-03-22
	Description:	Melhorado fluxo da trigger e leitura do código, documentado
					Adicionado registro na AD_CPENVIOS (Dentro da Controle de Pedidos) (Tabela de registro de envios, varios envios p/ mesmo pedido)
	
	Author:			Guilherme Branco Stracini
	Change date:	2017-03-30
	Description:	Verifica se o pedido possui código de rastreio (entrega digital / retirada no local não possuem) 
					antes de inserir na AD_CPENVIOS

	Author:			Guilherme Branco Stracini
	Change date:	2017-03-31
	Description:	Se não possuir etiqueta e deveria existir então cria a etiqueta via STP_GERAR_ETIQUETA_CORREIOS

	Author:			Guilherme Branco Stracini
	Change date:	2017-04-11
	Description:	Status 'N' no INSERT da CPENVIOS (Status é um campo novo, que indica qual status do monitoramento da entrega).
	
	Author:			Guilherme Branco Stracini
	Change date:	2017-04-24
	Description:	Localiza um fluxo de expedição não cadastrado na tabela de fluxos, que impede a geração de etiqueta.

	Author:			Guilherme Branco Stracini
	Change date:	2017-06-28
	Description:	Adiciona número do pedido original para pedidos de compra (TIPMOV = O)

	Author:			Rodrigo Lacalendola
	Change date:	2017-07-04
	Description:	Não permite faturar para TOP 505 caso o campo AD_STATUSPGTO não esteja com o valor 'E' (Pagamento Efetuado) ou 'F' (Faturado).

	Author:			Guilherme Branco Stracini
	Change date:	2017-07-07
	Description:	Adiciona o código do parceiro transportadora na nota 505 se não condizer com o cadatro na AD_MODTRANSP

	Author:			Guilherme Branco Stracini
	Change date:	2017-10-06
	Description:	Verifica se já existe pedido original com mesma numeração nas TOPs 500, 501 ou 502 se for uma nota da TOP 500, 501 ou 502

	Author:			Guilherme Branco Stracini
	Change date:	2017-10-09
	Description:	Cria pedido original para TOP 506 também

	Author:			Guilherme Branco Stracini
	Change date:	2017-10-10
	Description:	Gera a etiqueta para Correios, Mandaê e Mercado Livre

	Author:			Guilherme Branco Stracini
	Change date:	2018-02-19
	Description:	Adiciona o código do parceiro a tela Controle de Pedidos (requisito para o Visualizador de Pedidos V2 localizar os pedidos sem uma query exaustiva com vários joins)

	Author:			Guilherme Branco Stracini
	Change date:	2018-04-10
	Description:	No faturamento para a nota de venda (TOP 550) verifica se o CEP de entrega está cadastro na TSICEP, 
					caso não esteja lança erro, para evitar problemas coma a Mandaê / Correios.

	Author:			Guilherme Branco Stracini
	Change date:	2018-04-17
	Description:	Cadastra as TOPS de devolução na FLUXO (TOP não cadastrada: 602, 603, 605 e tira a 604 da lista)

	Author:			Guilherme Branco Stracini
	Change date:	2018-04-25
	Description:	Valida a criação de um pedido bonificado, se o pedido original teve baixa do pagamento. 
					Caso não tenha não permite o bonificado (para previnir erros), uma vez que se não tiver o pagamento no original
					o romaneio não será impresso (chamado YRB-44V-RZN3)
					
	Author:			Guilherme Branco Stracini
	Change date:	2018-05-04
	Description:	Corrigido trava criada em 25/04/2018 que estava no lugar errado e por isso não funcionava.
					Adicionado verificação de status de pagamento para TOP 550 além da 505 já existente, impedindo 
					de faturar o pedido caso não esteja	com pagamento efetuado.

	Author:			Guilherme Branco Stracini
	Change date:	2018-08-01
	Description:	Preenche os campos de BI (indexação Elastic Search) com o valor padrão N

	Author:			Guilherme Branco Stracini
	Change date:	2018-09-04
	Description:	Remove o cadastro na AD_PEDIDOSPARADOS

	Author:			Guilherme Branco Stracini
	Change date:	2018-09-13
	Description:	[BUG] Remove da AD_ITEMPARADO também para não dar erro de referência.
	
	============================================= */

ALTER TRIGGER [sankhya].[TRG_INC_TGFCAB_AD_PEDIDOVTEXSCFLUXO] 
   ON  [sankhya].[TGFCAB] 
   AFTER INSERT
AS 
DECLARE 
@NUNOTA INT,
@CODTIPOPER INT, 
@PEDORIGINAL INT,
@ORDERID VARCHAR(100),
@CHAVENFE VARCHAR(44),
@NUMERONFE INT,
@CODVEND INT,
@BONIFICADO VARCHAR(1),
@CODREENVIO INT,
@OCORRENCIA VARCHAR(1),
@CODUSU INT,
@CODPEDWMW INT,
@CODMODTRANSP INT,
@EMAIL VARCHAR(150),
@NOMEUSU VARCHAR(30),
@NOMEPARC VARCHAR(100),
@INFO VARCHAR(500),
@SUBJECT VARCHAR(150),
@SOLICITANTE VARCHAR(30),
@STATUSPGTO CHAR(1),
@TIPMOV CHAR(1),
@CODPARCTRANSP INT,
@CODPARC INT,
@CEP CHAR(8)
BEGIN
	SET NOCOUNT ON;

	SELECT @SOLICITANTE = SUBSTRING(program_name,1,30) 
	FROM MASTER.DBO.SYSPROCESSES WITH (NOLOCK) 
	WHERE SPID = @@SPID;

	/*
	 *	Obtem os dados da nota e o e-mail e nome do usuario/parceiro
	 */

	SELECT @NUNOTA =		I.NUNOTA, 
		   @CODTIPOPER =	I.CODTIPOPER, 
		   @CODVEND =		I.CODVEND, 
		   @CODUSU =		I.CODUSUINC,
		   @BONIFICADO =	I.AD_BONIFICADO, 
		   @CODREENVIO =	I.AD_CODREENVIO, 
		   @PEDORIGINAL =	I.AD_PEDORIGINAL,
		   @CHAVENFE =		I.CHAVENFE,
		   @CODPEDWMW =		I.AD_PEDIDOWMW, 
		   @NUMERONFE =		I.NUMNOTA,
		   @CODMODTRANSP =	I.AD_IDMOD,
		   @EMAIL =			U.EMAIL,
		   @NOMEUSU =		U.NOMEUSU,
		   @NOMEPARC =		P.NOMEPARC,
		   @STATUSPGTO =	I.AD_STATUSPGTO,
		   @TIPMOV =		I.TIPMOV,
		   @CODPARCTRANSP = I.CODPARCTRANSP,
		   @CODPARC =		I.CODPARC,
		   @CEP =			P.CEP
	FROM INSERTED AS I
	LEFT JOIN TSIUSU AS U WITH (NOLOCK)
	ON I.CODUSU = U.CODUSU
	LEFT JOIN TGFPAR AS P WITH (NOLOCK)
	ON I.CODPARC = P.CODPARC
	
	IF @CODTIPOPER IN (500, 501, 502)
	AND EXISTS (
		SELECT 1 
		FROM TGFCAB AS C WITH (NOLOCK)
		WHERE C.AD_PEDORIGINAL = @PEDORIGINAL 
		AND C.CODTIPOPER IN (500, 501, 502)
		AND C.NUNOTA != @NUNOTA)
	BEGIN
		RAISERROR('Já existe uma nota na TOP %i para o pedido original %i', 16, 1, @CODTIPOPER, @PEDORIGINAL);
		IF UPPER(@SOLICITANTE) LIKE 'MICROSOFT%'
		OR UPPER(@SOLICITANTE) = 'MS SQLEM'
		OR UPPER(@SOLICITANTE) = 'MS SQL QUERY ANALYZER'
			ROLLBACK TRANSACTION;
		RETURN;
	END

	/*
	 * Verifica se o CEP do parceiro existe na tabela de CEPs, caso contrário gera erro e impede o faturamento.	
	 */

	--IF @CODTIPOPER = 550
	--AND NOT EXISTS(SELECT 1 FROM TSICEP WITH (NOLOCK) WHERE CEP = @CEP)
	--BEGIN 
	--	IF @CEP IS NULL
	--		SET @CEP = '<SEM CEP>'; 
	--	RAISERROR('O CEP %s do parceiro não é válido no pedido original %i', 16, 1, @CEP, @PEDORIGINAL);
	--	IF UPPER(@SOLICITANTE) LIKE 'MICROSOFT%'
	--	OR UPPER(@SOLICITANTE) = 'MS SQLEM'
	--	OR UPPER(@SOLICITANTE) = 'MS SQL QUERY ANALYZER'
	--		ROLLBACK TRANSACTION;
	--	RETURN;
	--END

	IF @EMAIL IS NULL
		SET @EMAIL = 'logistica@editorainovacao.com.br';
	IF @NOMEUSU IS NULL
		SET @NOMEUSU = '<SEM USUÁRIO>';
	IF @NOMEPARC IS NULL
		SET @NOMEPARC = '<SEM NOME>';

	/*
	 * Para pedidos realizados no Sankhya:
	 * - 503 - Pedido Sankhya
	 * - 506 - Pedido de serviço
	 * - 511 - Pedido de tranferência (Movimentação interna)
	 * - 515 - LEADs
	 * - 520 - Pedido funcionário
	 * - Pedidos de Compra (TIPMOV = O) 
	 * - Movimentação interna (TIPMOV = J)
	 * Marca o Pedido Original como sendo o número da nota
	 */

	IF @CODTIPOPER IN (503, 506, 511, 515, 520, 522) 
	OR @TIPMOV IN ('J','O')
		SET @PEDORIGINAL = @NUNOTA;

	/*
	 * Se o Pedido Original for nulo, encerra a trigger
	 * * Diminuido um IF na trigger! - 22/03
	 */
	IF @PEDORIGINAL IS NULL
		RETURN;
	/*
	 * Obtem o order id do pedido na Controle de Pedidos
	 */
	SELECT @ORDERID = ORDERID FROM AD_PEDIDOVTEXSC WITH (NOLOCK) WHERE PEDORIGINAL = @PEDORIGINAL;

	/*
	 * Se o order id for nulo, não existe na controle de pedidos, então faz o cadastro (de acordo com a TOP)
	 * Obs.: Se a TOP for a 502 o cadastro deve ser feito pela Integração, exceto nos casos onde é TOP 502 mas o pedido foi veito no WMW
	 */
	
	IF @ORDERID IS NULL 
	AND (@CODTIPOPER IN (200, 500, 501, 503, 506, 511, 515, 520) 
		OR (@CODTIPOPER = 502 AND @CODPEDWMW IS NOT NULL)
		OR @TIPMOV = 'O')
	BEGIN
		IF @CODTIPOPER IN (200, 503, 506, 511, 515, 520)
		OR @TIPMOV = 'O'
		BEGIN
			UPDATE TGFCAB SET AD_PEDORIGINAL = @PEDORIGINAL WHERE NUNOTA = @NUNOTA;

			/*
			 * Se for pedido da TOP 506 ou 511 ou for pedido de compra (TIPMOV = O)
			 * Encerra a trigger para não adicionar o pedido na tela controle de pedidos.
			 */
			IF @CODTIPOPER IN (511)
			OR @TIPMOV = 'O'
				RETURN;
		END
		
		SELECT @ORDERID = (
			CASE 
			WHEN @CODTIPOPER IN (503, 506, 515, 520) THEN CONVERT(VARCHAR(100), @PEDORIGINAL) + '-Sankhya'
			ELSE CONVERT(VARCHAR(100), @PEDORIGINAL) + '-WMWVendas' 
			END
		);		
			
		/*
		 * Se não for da TOP abaixo ele não faz o insert na controle;
		*/
		 
		IF @CODTIPOPER = 200
			RETURN;
		
		INSERT INTO AD_PEDIDOVTEXSC (ORDERID, MARKETPLACEORDERID, PEDORIGINAL, CODLOJA, CODVEND, CODPROMOCAO, POSSUICURSODIGITAL, POSSUICANALDOARTESANATO, CODPARC, IDXPED, IDXITENS)
		VALUES (@ORDERID, @CODPEDWMW, @PEDORIGINAL, 0, @CODVEND, 0, 'N', 'N', @CODPARC, 'N', 'N');
		
		INSERT INTO AD_PEDIDOVTEXSCFLUXO (DATA, NUNOTA, OCORRENCIA, CODUSU, ORDERID, PEDORIGINAL)
		VALUES (GETDATE(), @NUNOTA, 'P', @CODUSU, @ORDERID, @PEDORIGINAL);
	END

	/*
	 * Se o order id não for nulo e o pedido for da top 504 (reenvio/bonificado)
	 * Insere ele na Controle Reenvio
	 */
	
	ELSE IF @ORDERID IS NOT NULL AND @CODTIPOPER = 504
	BEGIN
		
		/*
		 * Se for um pedido bonificado, verifica se o pedido orginal teve o pagamento realizado
		 */
		IF NOT EXISTS (SELECT 1 FROM AD_PEDIDOVTEXSCFLUXO WITH (NOLOCK) WHERE PEDORIGINAL = @PEDORIGINAL AND OCORRENCIA = 'B')
		BEGIN 
			RAISERROR('Não é possível gerar um pedido bonificado para o pedido %i, porque o pedido não teve o pagamento efetuado!', 16, 1, @PEDORIGINAL);
			IF UPPER(@SOLICITANTE) LIKE 'MICROSOFT%'
			OR UPPER(@SOLICITANTE) = 'MS SQLEM'
			OR UPPER(@SOLICITANTE) = 'MS SQL QUERY ANALYZER'
				ROLLBACK TRANSACTION;
			RETURN;
		END

		/*
		 * Se o pedido original for de um parceiro diferente do bonificado lança erro (Visualizado de Pedidos V2)
		 */
		IF NOT EXISTS (SELECT 1 FROM AD_PEDIDOVTEXSC WITH (NOLOCK) WHERE PEDORIGINAL = @PEDORIGINAL AND CODPARC = @CODPARC)
		BEGIN
			RAISERROR('O pedido %i pertence a um parceiro diferente do parceiro do pedido bonificado. Não pode alterar o parceiro do pedido bonificado', 16, 1, @PEDORIGINAL);
			IF UPPER(@SOLICITANTE) LIKE 'MICROSOFT%'
			OR UPPER(@SOLICITANTE) = 'MS SQLEM'
			OR UPPER(@SOLICITANTE) = 'MS SQL QUERY ANALYZER'
			ROLLBACK TRANSACTION;
			RETURN;
		END	
		
		SELECT @CODREENVIO = COUNT(CODREENVIO) + 1 
		FROM AD_PEDIDOVTEXSCREENVIO WITH (NOLOCK) 
		WHERE ORDERID = @ORDERID;
		
		UPDATE TGFCAB 
		SET AD_CODREENVIO = @CODREENVIO 
		WHERE NUNOTA = @NUNOTA;
		
		INSERT INTO AD_PEDIDOVTEXSCREENVIO (CODREENVIO, ORDERID, PEDORIGINAL, CODVEND)
		VALUES (@CODREENVIO, @ORDERID, @PEDORIGINAL, @CODVEND);
		
		INSERT INTO AD_PEDIDOVTEXSCREENVIOFLUXO (DATA, NUNOTA, OCORRENCIA, CODREENVIO, CODUSU, ORDERID, PEDORIGINAL)
		VALUES (GETDATE(), @NUNOTA, 'P', @CODREENVIO, @CODUSU, @ORDERID, @PEDORIGINAL);
	END

	/*
	 * Se o order id for nulo e o pedido for da top 504 (reenvio/bonificado)
	 * Lança erro informando que não é possível registrar um pedido bonificado para um pedido que não existe na controle
	 */
	
	ELSE IF @ORDERID IS NULL 
	AND @CODTIPOPER = 504
	BEGIN
		RAISERROR('O pedido %i não existe na Controle de Pedidos, não é possível criar um bonificado para ele', 16, 1, @PEDORIGINAL);
		IF UPPER(@SOLICITANTE) LIKE 'MICROSOFT%'
		OR UPPER(@SOLICITANTE) = 'MS SQLEM'
		OR UPPER(@SOLICITANTE) = 'MS SQL QUERY ANALYZER'
			ROLLBACK TRANSACTION;
		RETURN;
	END
	/*
	 * Se não for uma TOP de pedido e o order id não for nulo, cadastra os fluxos de acorodo com a TOP da nota
	 */
	ELSE IF @ORDERID IS NOT NULL
	BEGIN
		
		/*
		 * Verifica se foi faturado para a TOP 505 ou 550
		 * e se o campo status do pagamento (AD_STATUSPGTO) está com o valor E (Efetuado) ou F (Faturado).
		 * Se não estiver (P - Pendente, R - Estornado), não permite a operação e lança erro.
		 */	
		IF @CODTIPOPER IN (505, 550)
		AND @STATUSPGTO NOT IN ('E','F')
		BEGIN
			RAISERROR('Pedido %i está com o pagamento pendente ou estornado, não é possível faturar para a TOP %i', 16, 1, @PEDORIGINAL, @CODTIPOPER);
			IF UPPER(@SOLICITANTE) LIKE 'MICROSOFT%'
			OR UPPER(@SOLICITANTE) = 'MS SQLEM'
			OR UPPER(@SOLICITANTE) = 'MS SQL QUERY ANALYZER'
			ROLLBACK TRANSACTION;
		RETURN;
		END

		/* 
		 * Atualiza campo CODPARCTRANSP na TGFCAB se for 0 e o parceiro da modalidade de transporte não for 0
		 */

		IF @CODTIPOPER = 505
		AND @CODPARCTRANSP = 0
		AND EXISTS (
			SELECT 1
			FROM AD_MODTRANSPORTE AS M WITH (NOLOCK)
			WHERE M.IDMOD = @CODMODTRANSP
			AND M.CODPARC != 0
		)
			UPDATE TGFCAB
			SET CODPARCTRANSP = (SELECT CODPARC FROM AD_MODTRANSPORTE WITH (NOLOCK) WHERE IDMOD = @CODMODTRANSP)
			WHERE NUNOTA = @NUNOTA;
		
		/*
		 * Se for da TOP 505 e não for bonificado registra na controle o fluxo E (Expedição)
		 */
		IF @CODTIPOPER = 505 
		AND @BONIFICADO IS NULL
			INSERT INTO AD_PEDIDOVTEXSCFLUXO (DATA, NUNOTA, OCORRENCIA, CODUSU, ORDERID, PEDORIGINAL)
			VALUES (GETDATE(), @NUNOTA, 'E', @CODUSU, @ORDERID, @PEDORIGINAL);
		/*
		 * Se for da TOP 505 e for bonificado e existe o cadastro do pedido com o código de reenvio na controle reenvios
		 */
		ELSE IF @CODTIPOPER = 505 
		AND @BONIFICADO = 'S' 
		AND EXISTS(
			SELECT 1 
			FROM AD_PEDIDOVTEXSCREENVIO WITH (NOLOCK)
			WHERE PEDORIGINAL = @PEDORIGINAL 
			AND CODREENVIO = @CODREENVIO)
				INSERT INTO AD_PEDIDOVTEXSCREENVIOFLUXO (DATA, NUNOTA, OCORRENCIA, CODREENVIO, CODUSU, ORDERID, PEDORIGINAL)
				VALUES (GETDATE(), @NUNOTA, 'E', @CODREENVIO, @CODUSU, @ORDERID, @PEDORIGINAL);	
		
		/*
		 * Se for da TOP 550 e não for bonificado registra na controle o fluxo V (Venda)
		 * e cadastra a etiqueta na CPENVIOS
		 *
		 * Se a chave NF-e não for nula (faturado direto), já insere o fluxo N (NF-e) na Fluxo		 
		 */
		
		ELSE IF @CODTIPOPER = 550 
		AND @BONIFICADO IS NULL
		BEGIN
			INSERT INTO AD_PEDIDOVTEXSCFLUXO (DATA, NUNOTA, OCORRENCIA, CODUSU, ORDERID, PEDORIGINAL)
			VALUES (GETDATE(), @NUNOTA, 'V', @CODUSU, @ORDERID, @PEDORIGINAL);
				
			/*
			 * Gera a etiqueta (CPENVIOS) para essa nota
			 */
			EXEC STP_GERAR_ETIQUETA_TRANSPORTADORA @NUNOTA, @PEDORIGINAL, @ORDERID, @CODMODTRANSP;
			
			/*
			 * Remove o pedido da tabela AD_PEDIDOSPARADOS caso exista
			 */
			 DELETE FROM AD_ITEMPARADO WHERE NUNOTA IN (SELECT NUNOTA FROM TGFCAB WITH (NOLOCK) WHERE AD_PEDORIGINAL = @PEDORIGINAL);
			 DELETE FROM AD_PEDIDOSPARADOS WHERE NUNOTA IN (SELECT NUNOTA FROM TGFCAB WITH (NOLOCK) WHERE AD_PEDORIGINAL = @PEDORIGINAL);

			/*
			 *	Se a chave NF-e não for nula, insere fluxo N
			 */
			
			IF @CHAVENFE IS NOT NULL
				INSERT INTO AD_PEDIDOVTEXSCFLUXO (DATA, NUNOTA, OCORRENCIA, CODUSU, ORDERID, PEDORIGINAL)
				VALUES (GETDATE(), @NUNOTA, 'N', @CODUSU, @ORDERID, @PEDORIGINAL);		
		END

		/*
		 * Se for da TOP 550 e for bonificado e existe o cadastro do pedido com o Código de Reenvio na Controle Reenvios
		 */
		ELSE IF @CODTIPOPER = 550 
		AND @BONIFICADO = 'S' 
		AND EXISTS(
			SELECT 1 
			FROM AD_PEDIDOVTEXSCREENVIO WITH (NOLOCK)
			WHERE PEDORIGINAL = @PEDORIGINAL 
			AND CODREENVIO = @CODREENVIO)
		BEGIN 

			/* Insere fluxo V (Venda) na Controle Reenvio Fluxo*/
			INSERT INTO AD_PEDIDOVTEXSCREENVIOFLUXO (DATA, NUNOTA, OCORRENCIA, CODREENVIO, CODUSU, ORDERID, PEDORIGINAL)
			VALUES (GETDATE(), @NUNOTA, 'V', @CODREENVIO, @CODUSU, @ORDERID, @PEDORIGINAL);
			
			/*
			 * Gera a etiqueta (CPENVIOS) para essa nota
			 */
			EXEC STP_GERAR_ETIQUETA_TRANSPORTADORA @NUNOTA, @PEDORIGINAL, @ORDERID, @CODMODTRANSP;								

			/*
			 * Remove o pedido da tabela AD_PEDIDOSPARADOS caso exista
			 */
			 DELETE FROM AD_ITEMPARADO WHERE NUNOTA IN (SELECT NUNOTA FROM TGFCAB WITH (NOLOCK) WHERE AD_PEDORIGINAL = @PEDORIGINAL AND AD_CODREENVIO = @CODREENVIO);
			 DELETE FROM AD_PEDIDOSPARADOS WHERE NUNOTA IN (SELECT NUNOTA FROM TGFCAB WITH (NOLOCK) WHERE AD_PEDORIGINAL = @PEDORIGINAL AND AD_CODREENVIO = @CODREENVIO);

		    /*
			 *	Se a chave NF-e não for nula, insere fluxo N e atualiza controle
			 */
			IF @CHAVENFE IS NOT NULL
				INSERT INTO AD_PEDIDOVTEXSCREENVIOFLUXO (DATA, NUNOTA, OCORRENCIA, CODREENVIO, CODUSU, ORDERID, PEDORIGINAL)
				VALUES (GETDATE(), @NUNOTA, 'N', @CODREENVIO, @CODUSU, @ORDERID, @PEDORIGINAL);
		END
		
		/*
		 * Se for da TOP 562 insere o fluxo M (Venda Digital) na fluxo
		 */

		ELSE IF @CODTIPOPER = 562
		BEGIN 
			INSERT INTO AD_PEDIDOVTEXSCFLUXO (DATA, NUNOTA, OCORRENCIA, CODUSU, ORDERID, PEDORIGINAL)
			VALUES (GETDATE(), @NUNOTA, 'M', @CODUSU, @ORDERID, @PEDORIGINAL);
		
			/*
			 *	Se a chave NF-e não for nula, insere fluxo N e atualiza controle
			 */
			IF @CHAVENFE IS NOT NULL
				INSERT INTO AD_PEDIDOVTEXSCFLUXO (DATA, NUNOTA, OCORRENCIA, CODUSU, ORDERID, PEDORIGINAL)
				VALUES (GETDATE(), @NUNOTA, 'N', @CODUSU, @ORDERID, @PEDORIGINAL);
		END

		/*
		 * Se for da TOP 600, 601, 602, 603 ou 604 não for bonificado insere o fluxo D (Devolução) na fluxo
		 */

		ELSE IF @CODTIPOPER IN (600, 601, 602, 603, 605) 
		AND @BONIFICADO IS NULL
				INSERT INTO AD_PEDIDOVTEXSCFLUXO (DATA, NUNOTA, OCORRENCIA, CODUSU, ORDERID, PEDORIGINAL)
				VALUES(GETDATE(), @NUNOTA, 'D', @CODUSU, @ORDERID, @PEDORIGINAL);
		/*
		 * Se for da TOP 600, 601, 602, 603 ou 605 e for bonificado  e existe o cadastro do pedido com o Código de Reenvio na Controle Reenvios
		 * insere o fluxo D (Devolução) na fluxo reenvio
		 */
		ELSE IF @CODTIPOPER IN (600, 601, 602, 603, 605) 
		AND @BONIFICADO = 'S' 
		AND EXISTS(
			SELECT 1 
			FROM AD_PEDIDOVTEXSCREENVIO WITH (NOLOCK)
			WHERE PEDORIGINAL = @PEDORIGINAL 
			AND CODREENVIO = @CODREENVIO)
				INSERT INTO AD_PEDIDOVTEXSCREENVIOFLUXO (DATA, NUNOTA, OCORRENCIA, CODREENVIO, CODUSU, ORDERID, PEDORIGINAL)
				VALUES (GETDATE(), @NUNOTA, 'D', @CODREENVIO, @CODUSU, @ORDERID, @PEDORIGINAL);
	END
END