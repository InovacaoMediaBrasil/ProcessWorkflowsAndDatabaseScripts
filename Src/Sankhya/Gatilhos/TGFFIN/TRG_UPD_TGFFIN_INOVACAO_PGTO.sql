USE [SANKHYA_PRODUCAO]
GO
/****** Object:  Trigger [sankhya].[TRG_UPD_TGFFIN_INOVACAO_PGTO]    Script Date: 17/04/2018 12:10:17 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* =============================================
	Author:			Décio Bento Junior
	Create date:	2014-08-20
	Description:	Realiza a alteração do campo AD_STATUSPGTO na TGFCAB quando ocorrer a baixa ou estorno na TGFFIN de acordo com o campo DHBAIXA.
	
	Author:			Rodrigo Lacalendola
	Change date:	2016-06-25
	Description:	Valida se o VLRBAIXA é menor que o VLRDESDOB, caso seja e a forma de pagamento seja boleto/depósito lança uma mensagem de erro e anula a operação
					Caso seja não permite baixa, insere mensagem de erro na TGFCAB, TGFFIN e TGFACT e envia e-mails
	
	Author:	 		Guilherme Branco Stracini | Rafael Turra
	Change date:	2017-03-15
	Description:	Corrigido verificação do valor para verificar somente na baixa e não no estorno se o valor é menor (no estorno, sempre é porque estorno zera o valor!) (Rafael Turra | Guilherme Branco Stracini)
					Melhorado desempenho da trigger (Guilherme Branco Stracini)
					Corrigido Historico da TGFFIN caso possua mensagem automática ou esteja nulo (Rafael Turra)
				 
	Author:			Guilherem Branco Stracini
	Change date:	2017-03-24
	Description: 	Corrigido para só efetuar alterações em uma NUFIN por vez
					Não permite a baixa caso a nota não esteja confirmada (STATUSNOTA = 'L')

	Author:			Guilherme Branco Stracini
	Change date:	2017-03-27
	Description:	Verificado se o NUNOTA é nulo, se for encerra execução da trigger.
					Documentado.

	Author:			Guilherme Branco Stracini
	Change date:	2017-06-28
	Description:	Ao estornar um pagamento marca o campo AD_STATUSPGTO no pedido com o valor R de estorno para que o pedido não seja cancelado neste meio tempo pela Integração Service

	Author:			Guilherme Branco Stracini
	Change date:	2018-04-17
	Description:	Verfica se é um boleto e se o valor do boleto é maior do que o valor da movimentação (Erro na importação do pedido)
	============================================= */
ALTER TRIGGER [sankhya].[TRG_UPD_TGFFIN_INOVACAO_PGTO] 
   ON  [sankhya].[TGFFIN] 
   AFTER UPDATE
AS 
DECLARE	
@NUNOTA			INT,
@NUFIN			INT,
@DHBAIXA		DATETIME,
@VLRBAIXA		MONEY,
@VLRDESDOB		MONEY,
@VLRJURO		MONEY,
@CODTIPTIT		INT,
@CODTIPOPER		INT,
@PEDORIGINAL	INT,
@SEQUENCIA		INT,
@STATUS			CHAR(1),
@HISTORICO		VARCHAR(255),
@SOLICITANTE	CHAR(30),
@MENSAGEM		VARCHAR(255);
BEGIN
	SET NOCOUNT ON;

	/*
	 * Se a nota não atualizar o DHBAIXA encerra o gatilho
	 */
	IF NOT UPDATE(DHBAIXA)
		RETURN;

	/*
	 * Obtém os dados da movimentação financeira em questão
	 */
	SELECT 
		@NUNOTA =		I.NUNOTA,
		@NUFIN =		I.NUFIN,
		@DHBAIXA =		I.DHBAIXA,
		@VLRBAIXA =		I.VLRBAIXA,
		@VLRDESDOB =	I.VLRDESDOB,
		@VLRJURO =		I.VLRJURO,
		@CODTIPTIT =	I.CODTIPTIT,
		@CODTIPOPER =	I.CODTIPOPER,
		@HISTORICO =	I.HISTORICO
	FROM INSERTED AS I

	/*
	 * Se o NUNOTA (Número único) for nulo, encerra o gatilho.
	 */
	IF @NUNOTA IS NULL
		RETURN;

	/*
	 * Obtem o pedido original na TGFCAB pelo NUNOTA
	 */
	SELECT @PEDORIGINAL = AD_PEDORIGINAL
	FROM TGFCAB WITH (NOLOCK)
	WHERE NUNOTA = @NUNOTA;

	/*
	 * Obtém o nome do sistema que iniciou o gatilho, caso não seja o Sankhya, efetuara rollback em caso de erro
	 */

	SELECT @SOLICITANTE = program_name    
	FROM MASTER.DBO.SYSPROCESSES WITH (NOLOCK)
	WHERE SPID = @@SPID;   

	/*
	 * Se o campo DHBAIXA não for nulo
	 * Se o valor de baixa for menor do que o valor do título (esse é o problema real)
	 * Ou se o valor da baixa for maior do que o valor do título e for da TOP 502 (pedido importado errado)
	 * Se o título for do tipo 6, 10, 11, 13, 14 ou 15 (Boleto/Depósito)
	 * Se o tipo de operação for de pedido (500, 501, 502, 503, 515)
	 */
	-- VERIFICA SE O BALOR BAIXADO É MENOR DO QUE O VALOR NEGOCIADO, RETORNANDO MENSAGEM DE ERRO
    IF @DHBAIXA IS NOT NULL 
	AND (@VLRBAIXA < @VLRDESDOB OR (@VLRBAIXA > @VLRDESDOB AND @CODTIPOPER = 502))
	AND @CODTIPTIT IN (6, 10, 11, 13, 14, 15) 
	AND @CODTIPOPER IN (500, 501, 502, 503, 515)
    BEGIN

		/*
		 * Atualiza a observação da CAB para informar o problema
		 */
		UPDATE sankhya.TGFCAB 
		SET OBSERVACAO = 'Mensagem automática: Irregularidade no pagamento, favor consultar setor financeiro.' 
		WHERE NUNOTA = @NUNOTA

		IF @VLRBAIXA < @VLRDESDOB
			SET @MENSAGEM = 'Irregularidade no pagamento do pedido ' + CAST(@PEDORIGINAL AS VARCHAR) + ', o valor pago pelo cliente foi menor do que o valor devido. Cliente pagou R$' + CAST(@VLRBAIXA AS VARCHAR(10)) + ' e o valor devido é R$' + CAST(@VLRDESDOB AS VARCHAR(10)) + ' diferença de (-R$'+CAST((@VLRBAIXA-@VLRDESDOB) AS VARCHAR(10)) + ').';
		ELSE IF @CODTIPOPER = 502 AND @VLRDESDOB < @VLRBAIXA
			SET @MENSAGEM = 'Pedido ' + CAST(@PEDORIGINAL AS VARCHAR) + ' importado com itens faltando, por favor abra um chamado para que a importação seja realizada novamente.';

		/*
		 * Atualiza o histórico da FIN para informar o problema
		 */
		UPDATE sankhya.TGFFIN 
		SET HISTORICO = 'Mensagem automática:' + @MENSAGEM
		WHERE NUNOTA = @NUNOTA
		AND NUFIN = @NUFIN;

		/*
		 * Pega a próxima sequência da TGFACT para fazer o cadastro
		 */
		
		SELECT @SEQUENCIA = ISNULL(MAX(SEQUENCIA),0)+1 FROM sankhya.TGFACT WITH(NOLOCK) WHERE NUNOTA = @NUNOTA;

		/*
		 * Registra um acompanhamento (TGFACT) para a nota informando o problema
		 */
		INSERT INTO sankhya.TGFACT (NUNOTA,SEQUENCIA,DHOCOR,HRACT,OCORRENCIAS,DIGITADO) 
		VALUES (@NUNOTA, @SEQUENCIA, GETDATE(),	CAST(DATEPART(HOUR,GETDATE()) as varchar(2)) + CAST(DATEPART(MINUTE,GETDATE()) AS VARCHAR(2)),'Irregularidade no pagamento: valor pago (baixado) inferior ao valor devido (valor do desdobramento financeiro). Pedido NÃO foi marcado como Pagamento Efetuado.','N')
		
		/*
		 * Envia e-mail para o grupo administrativo@editorainovacao.com.br
		 */
		DECLARE @INFO VARCHAR(500), @SUBJECT AS VARCHAR(250)
		SET @SUBJECT = 'Irregularidade no pagamento pedido [' + CAST(@NUNOTA AS VARCHAR(6)) + ']'
		SET @INFO = 'O pedido de número único ' + cast(@PEDORIGINAL AS VARCHAR) + ' não será encaminhado à rotina de logística.' + @MENSAGEM + CHAR(13) + 'Favor analisar o pedido e dar andamento com os setores responsáveis.' 
	
		EXEC msdb.dbo.sp_send_dbmail
		@profile_name = 'SQLAlerts',
		@recipients = 'administrativo@editorainovacao.com.br;ti@editorainovacao.com.br;',
		@body = @INFO,
		@subject = @SUBJECT
    
		/*
		 * Lança mensagem de erro pro usuário
		 */
		IF @VLRBAIXA < @VLRDESDOB
			RAISERROR('Valor baixado é menor do que o valor do título. Baixa não autorizada! Contate o departamento de TI!', 16, 1);	
		ELSE IF @CODTIPOPER = 502 AND @VLRDESDOB < @VLRBAIXA
			RAISERROR('O valor da baixa é maior do que o valor do pedido, provavelmente foi um erro na importação! Conat o departamento de TI', 16, 1);

		/*
		 * Se o solicitante for alguns programas específicos, efetua rollback
		 */
		IF (UPPER(@SOLICITANTE) LIKE 'MICROSOFT%' OR
			UPPER(@SOLICITANTE) = 'MS SQLEM' OR 
			UPPER(@SOLICITANTE) = 'MS SQL QUERY ANALYZER' OR
			UPPER(@SOLICITANTE) LIKE 'TOAD%')
			ROLLBACK TRANSACTION;
		RETURN;
	END

	/*
	 *	Verifica se é um pedido (500, 501, 502, 503, 505, 515) e 
	 *  se a nota na CAB está confirmada (STATUSNOTA = 'L').
	 *  Se não estiver não permite a baixa.
	 */
	IF @CODTIPOPER IN (500, 501, 502, 503, 515)
	AND NOT EXISTS(SELECT 1 FROM sankhya.TGFCAB WITH (NOLOCK) WHERE NUNOTA = @NUNOTA AND STATUSNOTA = 'L')
	BEGIN
		RAISERROR('A nota precisa estar confirmada para que possa ser efetuada a baixa', 16, 1);

		IF (UPPER(@SOLICITANTE) LIKE 'MICROSOFT%' OR
			UPPER(@SOLICITANTE) = 'MS SQLEM' OR 
			UPPER(@SOLICITANTE) = 'MS SQL QUERY ANALYZER' OR
			UPPER(@SOLICITANTE) LIKE 'TOAD%')
			ROLLBACK TRANSACTION;
		RETURN;
	END
 
	/*
	 * Define qual será o status do pagamento será atualizado na TGFCAB de acordo com o campo DHBAIXA da FIN
	 * Se o campo for nulo, o status é pagamento estornado (R)(Estornado), se estiver preenchido é pagamento efetuado (E)(BAIXA)
	 */
	SELECT @STATUS = (CASE WHEN @DHBAIXA IS NULL THEN 'R' ELSE 'E' END);

	/*
	 * Atualiza o campo AD_STATUSPGTO na CAB para esta nota
	 */
	UPDATE TGFCAB
	SET AD_STATUSPGTO = @STATUS 
	WHERE NUNOTA = @NUNOTA;

	/*
	 * Se a nota for das tops 500, 5001, 502, 503 ou 5015, 
	 * atualiza também outras possiveis notas que já existam (505, 550, 562, 508, 509, 556, 558)
	 * de acordo com o AD_CODREENVIO (para não atualizar pedidos bonificados, por engano, caso existam)
	 */

	IF @CODTIPOPER IN (500, 501, 502, 503, 515)
		UPDATE TGFCAB SET AD_STATUSPGTO = @STATUS 
		WHERE AD_PEDORIGINAL = @PEDORIGINAL
		AND CODTIPOPER != @CODTIPOPER
		AND (AD_CODREENVIO IS NULL OR AD_CODREENVIO = 0)
	
	/*
	 * Se o histórico atual possuir a mensagem "Mensagem automática" ou for em branco ou nulo, insere uma mensagem padrão
	 * informando o que aconteceu com o pedido (baixa ou estorno) e a hora que ocorreu, apenas para log.
	 */
	IF (@HISTORICO LIKE 'Mensagem automática:%' OR @HISTORICO = '' OR @HISTORICO IS NULL)
	BEGIN
		SELECT @HISTORICO = (
		CASE WHEN @DHBAIXA IS NULL 
			THEN 'Mensagem automática: Estorno realizado em ' + CONVERT(VARCHAR, GETDATE(), 120)
			ELSE 'Mensagem automática: Baixa realizada com sucesso em ' + CONVERT(VARCHAR, GETDATE(), 120)
			END
		)
		UPDATE TGFFIN SET HISTORICO = @HISTORICO WHERE NUNOTA = @NUNOTA AND NUFIN = @NUFIN;
	END
END