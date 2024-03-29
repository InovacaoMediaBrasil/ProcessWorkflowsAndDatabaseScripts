USE [SANKHYA_PRODUCAO]
GO
/****** Object:  StoredProcedure [sankhya].[STP_VALIDAITEM_MULTILOJA_INOVACAO]    Script Date: 10/05/2017 14:15:20 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*	=============================================
	Author:			Decio B. Júnior
	Create date:	2014-12-03
	Description:	Controle de inserção de itens no Sankhya-W

	Author:			Guilherme Branco Stracini
	Change date:	2017-03-29
	Description:	Melhorias nas queries e utilização de WITH (NOLOCK).
					Corrigido verificação de valor do campo ATIVO na tabela AD_PRODUTOLOJA, os valores são 'S' e 'N' e estava sendo verificado 
					o valor 'NÃO'.
					Documentação

	Author:			Guilherme Branco Stracini
	Change date:	2017-03-30
	Description:	Ao invés de enviar e-mail para o HELP, faz o INSERT na controle para pedidos para pedidos 500, 501, 503 ou 515
					ou insert importação de pedidos pendente, para pedidos da TOP 502.
					Se o pedido (nota) não for de nenhuma dessas TOPS, ainda abre chamado para análise.
	=============================================*/
ALTER PROCEDURE [sankhya].[STP_VALIDAITEM_MULTILOJA_INOVACAO]
	-- Add the parameters for the stored procedure here
	@P_NUNOTA INT, 
	@P_SEQUENCIA INT, 
	@P_SUCESSO VARCHAR OUTPUT, 
	@P_MENSAGEM VARCHAR(500) OUTPUT, 
	@P_CODUSULIB NUMERIC OUTPUT
AS
DECLARE
@CODLOJA INT,
@NOMELOJA VARCHAR(40),
@ATIVO CHAR,
@CODPROD INT,
@CODTIPOPER INT,
@CODUSU INT,
@PEDORIGINAL INT,
@NOMEUSU VARCHAR(30),
@NOMEPARC VARCHAR(150),
@EMAIL VARCHAR(130),
@INFO VARCHAR(700),
@SUBJECT VARCHAR(200),
@CODVEND INT,
@PRODUTO VARCHAR(60),
@ORDERID VARCHAR(100);
BEGIN

	SET NOCOUNT ON;
	
	/*
	 * Obtem os dados para utilização na procedure.
	 */
	SELECT	@PEDORIGINAL =	C.AD_PEDORIGINAL,	/* Pedido original */
			@ORDERID =		P.ORDERID,
			@CODLOJA =		P.CODLOJA,		/* Código da loja */
			@NOMELOJA =		L.NOMELOJA,		/* Nome do canal de vendas (loja) (mensagem de erro / e-mail) */
			@CODTIPOPER =	C.CODTIPOPER,	/* Código de operação (para insert na controle de pedidos) */
			@CODVEND =		C.CODVEND		/* Código do vendedor (para insert na controle de pedidos) */
	FROM TGFCAB AS C WITH (NOLOCK)
	LEFT JOIN AD_PEDIDOVTEXSC AS P WITH (NOLOCK)
	ON P.PEDORIGINAL = C.AD_PEDORIGINAL
	LEFT JOIN AD_LOJA AS L WITH (NOLOCK)
	ON L.CODLOJA = P.CODLOJA
	WHERE C.NUNOTA = @P_NUNOTA;

	/*
	 *	Obtem o código do produto e o usuário (CODUSU, NOMEUSU, NOMEPARC, EMAIL) 
	 *  que fez a inserção na TGFITE
	 *  (as validações ignoram o usuário INTEGRAÇÃO - CODUSU 67)
	 */

	SELECT	@CODPROD =	I.CODPROD,	/* Código do produto para verificar e p/ mensagem de erro */
			@PRODUTO =	C.DESCRPROD + ISNULL(C.COMPLDESC, ''),
			@CODUSU =	U.CODUSU,	/* Código do usuário para verificar se não é a Integração */
			@NOMEUSU =	U.NOMEUSU,	/* Nome do usuário para envio de e-mail */
			@NOMEPARC = P.NOMEPARC, /* Nome real do usuário para envio do e-mail */
			@EMAIL =	U.EMAIL		/* Endereço de e-mail do usuário para responder o e-mail */
	FROM TGFITE AS I WITH (NOLOCK) 
	INNER JOIN TGFPRO AS C WITH (NOLOCK)
	ON I.CODPROD = C.CODPROD
	INNER JOIN TSIUSU AS U WITH (NOLOCK)
	ON U.CODUSU = I.CODUSU
	LEFT JOIN TGFPAR AS P WITH (NOLOCK)
	ON P.CODPARC = U.CODPARC
	WHERE NUNOTA = @P_NUNOTA
	AND SEQUENCIA = @P_SEQUENCIA;

	/*
	 *	Obtém o valor da flag ATIVO na AD_PRODUTOLOJA para o produto.
	 */
	SELECT @ATIVO = P.ATIVO
	FROM sankhya.AD_PRODUTOLOJA AS P WITH (NOLOCK)
	WHERE CODLOJA = @CODLOJA
	AND CODPROD = @CODPROD;

	/*
	 * Pré marca a regra de negócio como sucesso, se não parar em nenhuma das validações abaixo, executa normalmente.
	 */
	SET @P_SUCESSO = 'S';
	
	/*
	 * Se o código da loja for nulo e o usuário não for a Integração (67)
	 * tenta cadastrar o pedido na Controle de Pedidos (se for de uma TOP que permita)
	 * Se o código do usuário for 67 (Integração) não faz nada, porque a Integração faz o cadastro no final do processo!
	 */
	IF @CODLOJA IS NULL
	AND @CODUSU != 67
	BEGIN
		
		/*
		 * Tenta cadastrar o pedido na Controle de Pedidos
		 * Se for da TOP 500, 501, 503 ou 515 faz o insert direto na Controle de pedidos
		 * do pedido na VTEX também.
		 */
		IF @CODTIPOPER IN (500, 501, 503, 515)
		BEGIN 
			
			
			IF @CODTIPOPER IN (500,501)
				SET @ORDERID = CAST(@PEDORIGINAL AS VARCHAR) + '-WMWVendas';
			ELSE
				SET @ORDERID = CAST(@PEDORIGINAL AS VARCHAR) + '-Sankhya';

			/*
			 * Insere o pedido na Controle de Pedidos
			 */
			INSERT INTO AD_PEDIDOVTEXSC (CODLOJA, CODVEND, ORDERID, PEDORIGINAL, POSSUICANALDOARTESANATO, POSSUICURSODIGITAL)
			VALUES(0, @CODVEND, @ORDERID, @PEDORIGINAL, 'N', 'N');

			/*
			 * Insere o fluxo P (Pedido) na Controle de Pedidos - Fluxo
			 */
			INSERT INTO AD_PEDIDOVTEXSCFLUXO (CODUSU, DATA, NUNOTA, OCORRENCIA, ORDERID, PEDORIGINAL)
			VALUES (@CODUSU, GETDATE(), @P_NUNOTA, 'P', @ORDERID, @PEDORIGINAL);			
		END

		/*
		 * Se for da TOP 502 (VTEX), faz o INSERT na Pedidos com Importação Pendente 
		 * para a Integração fazer o tratamento dos dados adicionais (order id, promoção, etc)
		 */	
		ELSE IF @CODTIPOPER = 502
		BEGIN

			/*
			 * Informa o usuário que pode demorar até uma hora para o pedido ser cadastrado na Controle de Pedidos
			 * Já que a integração executa de hora em hora
			 */

			SET @P_SUCESSO = 'N';
			SET @P_MENSAGEM = 'O pedido não está cadastrado na tela controle de pedidos, mas já foi adicionado a fila da Integração.' + CHAR(13) + CHAR(10) +
							   'Em até 1 hora ele deve ser processado, caso não ocorra, entre em contato com o departamento de TI';

			ROLLBACK TRANSACTION;

			/*
			 * Faz o insert na importação de pedidos pendentes para a integração obter o pedido
			 * caso ele ainda não exista na tabela.
			 */

			IF NOT EXISTS (
				SELECT 1
				FROM AD_IMPORTACAOPEDPENDENTE WITH (NOLOCK)
				WHERE CODPED = @PEDORIGINAL)
			INSERT INTO sankhya.AD_IMPORTACAOPEDPENDENTE (CODPED, [STATUS], CODUSU) 
			VALUES (@PEDORIGINAL, 'M', @CODUSU);				
			
			COMMIT TRANSACTION;
			
		END
						
		/*
		 * Se o pedido não for de nenhuma TOP que possibilite automatizar o processo, ainda abre chamado para o TI.
		 */
		ELSE
		BEGIN
			
			/*
			 * Informa usuário que foi aberto um chamado para resolver o problema
 			 */
			SET @P_SUCESSO = 'N';
			SET @P_MENSAGEM = 'O pedido original ' + CAST(@PEDORIGINAL AS VARCHAR) + ' não está cadastrado na tela Controle de Pedidos.' + CHAR(13) + CHAR(10) + 
							  'Um chamado será aberto para a equipe de TI, caso não seja resolvido em até 2 horas, por favor entre em contato com o departamento de TI pessoalmente.';


			ROLLBACK TRANSACTION;

			/*
			* Envia um e-mail para o HELP abrindo um chamado para a TI cadastrar o pedido na Controle de Pedidos e verificar porque não foi cadastrado.
			*/
			
			SET @SUBJECT = 'Pedido não cadastrado na Controle de Pedidos - TOP ' + CAST(@CODTIPOPER AS VARCHAR);
						SET @INFO = 'O pedido original ' + CAST(@PEDORIGINAL AS VARCHAR) + ' - TOP ' + CAST(@CODTIPOPER AS VARCHAR) + ' não está cadastrado na tela Controle de Pedidos.' 
	
			EXEC msdb.dbo.sp_send_dbmail
			@profile_name = 'SQLAlerts',
			@from_address = @EMAIL,
			@reply_to = @EMAIL,
			@recipients = 'help@editorainovacao.com.br;',
			@copy_recipients = @EMAIL,
			@body = @INFO,
			@body_format = 'HTML',
			@subject = @SUBJECT

			COMMIT TRANSACTION;
		END
	END

	/*
	 * Se o fluxo "Pedido" não estiver cadastrado na fluxo, mas o pedido estiver na controle de pedidos,
	 * faz o cadastro do fluxo P
	 */

	IF NOT EXISTS(
		SELECT 1
		FROM AD_PEDIDOVTEXSCFLUXO AS F WITH (NOLOCK)
		WHERE F.PEDORIGINAL = @PEDORIGINAL
		AND OCORRENCIA = 'P')
	AND @CODTIPOPER IN (500, 501, 502, 503, 515)
	AND @CODUSU != 67
	AND @CODLOJA IS NOT NULL
		INSERT INTO AD_PEDIDOVTEXSCFLUXO (CODUSU, DATA, NUNOTA, OCORRENCIA, ORDERID, PEDORIGINAL)
		VALUES (@CODUSU, GETDATE(), @P_NUNOTA, 'P', @ORDERID, @PEDORIGINAL);


	/*
	 * Se o código da loja não for nulo, significa que está na controle de pedidos
	 * E o usuário não for a Integração
	 * E o produto não está ativo na top da loja do pedido
	 * Informa o usuário para liberar a venda neste canal de vendas com o departamento de cadastro
	 */

	
	IF @CODLOJA IS NOT NULL 
	AND @CODUSU != 67
	AND (@ATIVO = 'N' OR @ATIVO IS NULL)
	BEGIN
		
		/*
		 * Marca sucesso como N e informa usuário que o produto não está liberado no canal de vendas e informa que o dept. de cadastro foi avisado da solicitação
		 */
		 
		SET @P_SUCESSO = 'N';
		SET @P_MENSAGEM = 'O produto ' + CAST(@CODPROD AS VARCHAR) + ' não está liberado para o canal de vendas: ' + @NOMELOJA + '.' + CHAR(13) + CHAR(10) + 
		'Foi enviado um e-mail para o departamento de cadastro analisar sua solicitação.'; 

		/*
		 * Envia e-mail para o departamento de cadastro informando a solicitação do usuário em adicionar o produto no pedido de um canal de vendas não liberado.
		 */
		SET @SUBJECT = 'Produto ' + CAST(@CODPROD AS VARCHAR) + ' não liberado para o canal de vendas ' + @NOMELOJA;
		SET @INFO = 'O usuário <b>' + RTRIM(LTRIM(@NOMEUSU)) + ' - ' + RTRIM(LTRIM(@NOMEPARC)) + '</b> gostaria de adicionar o produto <b>' + CAST(@CODPROD AS VARCHAR) + ' - ' + RTRIM(LTRIM(@PRODUTO)) + '</b> no pedido <b>' + CAST(@PEDORIGINAL AS VARCHAR) + '</b>, porém o produto não está liberado para o canal de vendas <b>' + @NOMELOJA + '</b> na tela <b>MULTILOJAS->Canais de vendas</b>.<br /><br />Por favor efetue a liberação se possível e comunique o usuário para que ele possa fazer a inclusão novamente!' +
		+ '<br /><br /><br /><b>Obs.:</b> O usuário está em cópia no e-mail!';
			
		ROLLBACK TRANSACTION;

		EXEC msdb.dbo.sp_send_dbmail
		@profile_name = 'SQLAlerts',
		@from_address = @EMAIL,
		@reply_to = @EMAIL,
		@recipients = 'compras@editorainovacao.com.br;cadastro@editorainovacao.com.br',
		@copy_recipients = @EMAIL,
		@body = @INFO,
		@body_format = 'HTML',
		@subject = @SUBJECT

		COMMIT TRANSACTION;
	END
END