USE [SANKHYA_PRODUCAO]
GO
/****** Object:  Trigger [sankhya].[TRG_UPD_TGFCAB_AD_PEDIDOVTEXSCFLUXO]    Script Date: 04/05/2018 14:34:27 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* =============================================
	Author:			Guilherme Branco Stracini
	Create date:	2014-02-25
	Description:	Detecta quando ocorre a baixa de pagamento de um pedido ou quando é gerada a chave de NF-e (não faturado direto, gerado via UPDATE)
					e cadastra o fluxo na Controle de Pedidos

	Author:			Guilherme Branco Stracini
	Change date:	2017-03-22
	Description:	Corrigido alguns bugs que surgiram com alterações na TRG_UPD_TGFFIN_INOVACAO_PGTO.
					Removido tratamento para AD_PEDIDOVTEXSCASSINATURA já que não existem mais assinaturas no Sankhya.
					Documentado a trigger

	Author:			Guilherme Branco Stracini
	Change date:	2017-03-31
	Description:	Valida se a nota da 505 (Expedição) deve ter etiqueta, e gera etiqueta para ela via
					STP_GERAR_ETIQUETA_CORREIOS

	Author:			Guilherme Branco Stracini
	Change date:	2017-10-10
	Description:	Alterado para considerar o produto 6887 também como Assinatura do Canal do Artesanato além do 12744.
					Alterado geração de etiqueta, não é mais gerada na 505 e sim na 550 via trigger de INC!

	Author:			Guilherme Branco Stracini
	Change date:	2018-02-19
	Description:	Detecta quando ocorreu a troca do parceiro no pedido original e atualiza na controle de pedidos

	Author:			Guilherme Branco Stracin
	Change date:	2018-05-04
	Description:	Altera o código do tipo de venda (e da data do tipo de venda) caso seja alterado em uma das notas

	============================================= */
ALTER TRIGGER [sankhya].[TRG_UPD_TGFCAB_AD_PEDIDOVTEXSCFLUXO] 
   ON  [sankhya].[TGFCAB] 
   AFTER UPDATE
AS 
DECLARE 
@NUNOTA			INT,
@PEDORIGINAL	INT,
@PEDORIGINALANT	INT,
@CODTIPOPER		INT,
@ORDERID		VARCHAR(100),
@BONIFICADO		VARCHAR(1),
@CODREENVIO		INT,
@CODVEND		INT,
@CODUSU			INT,
@STATUSPGTO		CHAR(1),
@OCORRENCIA		VARCHAR(1),
@STATUSNOTA		CHAR(1),
@CODMODTRANSP	INT,
@SOLICITANTE	VARCHAR(30),
@CODPARC		INT,
@CODTIPVENDA	INT,
@DHTIPVENDA		DATETIME;
BEGIN
	SET NOCOUNT ON;

	SELECT @SOLICITANTE = SUBSTRING(program_name,1,30) 
	FROM MASTER.DBO.SYSPROCESSES WITH (NOLOCK) 
	WHERE SPID = @@SPID;

	/* 
	 * Obtem os dados da nota que foi atualizada 
	 */
	SELECT	@NUNOTA =			I.NUNOTA,
			@PEDORIGINAL =		I.AD_PEDORIGINAL,
			@PEDORIGINALANT =	D.AD_PEDORIGINAL,
			@CODUSU =			I.CODUSUINC,
			@CODVEND =			I.CODVEND,
			@STATUSPGTO =		I.AD_STATUSPGTO,
			@CODTIPOPER =		I.CODTIPOPER,
			@CODREENVIO =		I.AD_CODREENVIO,
			@STATUSNOTA =		I.STATUSNOTA,
			@CODMODTRANSP =		I.AD_IDMOD,
			@CODPARC =			I.CODPARC,
			@CODTIPVENDA =		I.CODTIPVENDA,
			@DHTIPVENDA =		I.DHTIPVENDA
	FROM	INSERTED AS I 
	INNER JOIN DELETED AS D ON (D.NUNOTA = I.NUNOTA) 
	WHERE	I.CODTIPOPER IN (500, 501, 502, 503, 504, 505, 515, 550, 562);
	
	/*
	 * Checa se a nota é nula, se for é porque não é de nenhuma TOP das que são tratadas neste gatilho.
	 */
	IF @NUNOTA IS NULL
		RETURN;

	/*
	 * Verifica se houve alteração do pedido original, se houve não permite a alteração.
	 * Para não ficar com erro na tela Controle de Pedidos (pedido fantasma)
	 */
	
	IF @PEDORIGINAL != @PEDORIGINALANT
	BEGIN
		RAISERROR('Não é permitido alterar um número de pedido original após criação da nota!', 16, 1);
		IF UPPER(@SOLICITANTE) LIKE 'MICROSOFT%'
		OR UPPER(@SOLICITANTE) = 'MS SQLEM'
		OR UPPER(@SOLICITANTE) = 'MS SQL QUERY ANALYZER'
			ROLLBACK TRANSACTION;
		RETURN;
	END
	

	/*
	 * Se foi alterado o status da nota (Confirmada ?) ou o status do pagamento (Baixa ?)
	 * e existe um produto 6887 ou 12744 (Canal do Artesanato) na ITE para esta nota
	 * Atualiza a flag na Controle informando que a nota possui assinatura do Canal do Artesanato
	 *
	 * Se for uma baixa e o status do pagamento for efetuado (AD_STATUSPGTO = E), marca o item da assinatura como não pendente na ITE
	 * e se o único produto na nota for ele, marca a nota também como não pendente 
	 */
	IF (UPDATE(STATUSNOTA) OR UPDATE(AD_STATUSPGTO))
		AND EXISTS(
			SELECT 1 
			FROM TGFITE AS I WITH (NOLOCK) 
			WHERE I.NUNOTA = @NUNOTA 
			AND I.CODPROD IN (6887, 12744)) 
	BEGIN
		UPDATE AD_PEDIDOVTEXSC SET POSSUICANALDOARTESANATO = 'S' WHERE PEDORIGINAL = @PEDORIGINAL;
		IF(@STATUSPGTO) = 'E'
		BEGIN
			UPDATE TGFITE SET QTDENTREGUE = QTDNEG, PENDENTE = 'N' WHERE CODPROD IN (6887, 12744) AND NUNOTA = @NUNOTA;
			IF NOT EXISTS (SELECT 1 FROM TGFITE AS I WITH (NOLOCK) WHERE I.NUNOTA = @NUNOTA AND I.CODPROD NOT IN (6887, 12744)) 
				UPDATE TGFCAB SET PENDENTE = 'N' WHERE NUNOTA = @NUNOTA;
		END
	END

	/*
	 * Se foi alterado o status do pagamento (baixa / estorno)
	 * e o valor é diferente do antigo (verificar se o UPDATE(CAMPO) só retorna true se o valor foi alterado de fato, se sim, a comparação é desnecessária)
	 * e a nota não for nula e nem o pedido original
	 * e for uma nota das TOPs 500, 501, 502, 503 ou 515
	 * Obtém o order id (para cadastrar novo fluxo, se for preciso)
	 * Atualiza as outras notas na CAB (expedição/nota) caso existam
	 */

	IF UPDATE(AD_STATUSPGTO)
	AND @NUNOTA IS NOT NULL 
	AND @PEDORIGINAL IS NOT NULL 
	AND @CODTIPOPER IN (500, 501, 502, 503, 515)
	BEGIN
		SELECT @ORDERID = ORDERID FROM sankhya.AD_PEDIDOVTEXSC WITH (NOLOCK) WHERE PEDORIGINAL = @PEDORIGINAL;
		UPDATE sankhya.TGFCAB SET AD_STATUSPGTO = @STATUSPGTO WHERE AD_PEDORIGINAL = @PEDORIGINAL AND CODTIPOPER IN (505, 550) AND AD_CODREENVIO = @CODREENVIO;
		
		/*
		 * Se o OrderId não for nulo (o pedido existe na controle):
		 * 
		 * Seleciona o código do usuário da baixa e qual será a ocorrencia de acordo com o status pgto
		 * Se a ocorrencia já existir na Fluxo, apenas atualiza a data e o código do usuário
		 * Se a ocorrencia for de baixa remove também qualquer ocorrência de estorno
		 * Se a ocorrencia não exisitr faz o insert na Fluxo
		 */		
		IF @ORDERID IS NOT NULL
		BEGIN
			SELECT @CODUSU = ISNULL(CODUSUBAIXA, ISNULL((SELECT CODUSU FROM TGFCAB WHERE NUNOTA = @NUNOTA), 0)) FROM sankhya.TGFFIN WITH (NOLOCK) WHERE NUNOTA = @NUNOTA;
			SELECT @OCORRENCIA = CASE WHEN @STATUSPGTO IN ('E','F') THEN 'B' ELSE 'R' END;
			IF EXISTS(
				SELECT 1 
				FROM AD_PEDIDOVTEXSCFLUXO WITH (NOLOCK) 
				WHERE NUNOTA = @NUNOTA 
				AND OCORRENCIA = @OCORRENCIA
				AND ORDERID = @ORDERID 
				AND PEDORIGINAL = @PEDORIGINAL)
			BEGIN
				UPDATE AD_PEDIDOVTEXSCFLUXO 
				SET DATA = GETDATE(), CODUSU = @CODUSU
				WHERE NUNOTA = @NUNOTA 
				AND OCORRENCIA = @OCORRENCIA
				AND ORDERID = @ORDERID 
				AND PEDORIGINAL = @PEDORIGINAL; 

				IF @OCORRENCIA = 'B'					
					DELETE FROM AD_PEDIDOVTEXSCFLUXO 
					WHERE NUNOTA = @NUNOTA 
					AND OCORRENCIA = 'R' 
					AND ORDERID = @ORDERID 
					AND PEDORIGINAL = @PEDORIGINAL;
			END
			ELSE
				INSERT INTO AD_PEDIDOVTEXSCFLUXO (DATA, NUNOTA, OCORRENCIA, CODUSU, ORDERID, PEDORIGINAL)
				VALUES (GETDATE(), @NUNOTA, @OCORRENCIA, @CODUSU, @ORDERID, @PEDORIGINAL);
		END
	END
	
	/*
	 * Se atualizar a chave da NF-e atualiza o valor da Chave NF-e, número da nota na Controle ou na Controle Reenvios
	 */
	IF UPDATE(CHAVENFE) 
	AND EXISTS(SELECT 1 FROM TGFCAB WITH (NOLOCK) WHERE NUNOTA = @NUNOTA AND CHAVENFE IS NOT NULL)
	BEGIN
		SELECT @ORDERID = ORDERID 
		FROM AD_PEDIDOVTEXSCFLUXO WITH (NOLOCK)
		WHERE PEDORIGINAL = @PEDORIGINAL
		AND NUNOTA = @NUNOTA;

	    /*
		 * Controle de Pedidos (pedido normal)
		 */

		IF @ORDERID IS NOT NULL 
		AND NOT EXISTS(
			SELECT 1 
			FROM AD_PEDIDOVTEXSCFLUXO WITH (NOLOCK) 
			WHERE PEDORIGINAL = @PEDORIGINAL 
			AND OCORRENCIA = 'N' 
			AND NUNOTA = @NUNOTA)
			INSERT INTO AD_PEDIDOVTEXSCFLUXO (DATA, NUNOTA, OCORRENCIA, CODUSU, ORDERID, PEDORIGINAL)
			VALUES (GETDATE(), @NUNOTA, 'N', @CODUSU, @ORDERID, @PEDORIGINAL);			

		/*
		 * Controle de Pedidos - Reenvios (bonificado / reenvio)
		 */
		ELSE
		BEGIN
			SELECT @ORDERID = ORDERID, @CODREENVIO = CODREENVIO 
			FROM AD_PEDIDOVTEXSCREENVIOFLUXO WITH (NOLOCK) 
			WHERE PEDORIGINAL = @PEDORIGINAL 
			AND NUNOTA = @NUNOTA;

			IF @ORDERID IS NOT NULL 
			AND @CODREENVIO IS NOT NULL 
			AND NOT EXISTS(
				SELECT 1 
				FROM AD_PEDIDOVTEXSCREENVIOFLUXO WITH (NOLOCK)
				WHERE PEDORIGINAL = @PEDORIGINAL 
				AND CODREENVIO = @CODREENVIO 
				AND OCORRENCIA = 'N' 
				AND NUNOTA = @NUNOTA)
				INSERT INTO AD_PEDIDOVTEXSCREENVIOFLUXO (DATA, NUNOTA, OCORRENCIA, CODUSU, CODREENVIO, ORDERID, PEDORIGINAL)
				VALUES (GETDATE(), @NUNOTA, 'N', @CODUSU, @CODREENVIO, @ORDERID, @PEDORIGINAL);
		END
	END
	
	/*
	 * Se o código do vendedor foi alterado atualiza o código do vendedor na Controle ou na Controle Reenvio.
	 */
	
	IF UPDATE(CODVEND) AND @CODTIPOPER IN (500, 501, 502, 503, 515)
	BEGIN
		UPDATE AD_PEDIDOVTEXSC SET CODVEND = @CODVEND WHERE PEDORIGINAL = @PEDORIGINAL;
		UPDATE TGFCAB SET CODVEND = @CODVEND WHERE AD_PEDORIGINAL = @PEDORIGINAL AND (AD_CODREENVIO = 0 OR AD_CODREENVIO IS NULL) AND NUNOTA != @NUNOTA;
	END
	ELSE IF UPDATE(CODVEND) AND @CODTIPOPER = 504
	BEGIN
		SELECT @NUNOTA = NUNOTA, @PEDORIGINAL = AD_PEDORIGINAL, @CODVEND = CODVEND FROM INSERTED;
		SELECT @CODREENVIO = CODREENVIO FROM sankhya.AD_PEDIDOVTEXSCREENVIOFLUXO WITH (NOLOCK) WHERE NUNOTA = @NUNOTA AND PEDORIGINAL = @PEDORIGINAL;
		IF @CODREENVIO IS NOT NULL
			UPDATE sankhya.AD_PEDIDOVTEXSCREENVIO SET CODVEND = @CODVEND WHERE CODREENVIO = @CODREENVIO AND PEDORIGINAL = @PEDORIGINAL;
	END	

	/*
	 *	Se houver alteração do código do parceiro atualiza o código do parceiro na Controle de Pedidos
	 */
	IF UPDATE(CODPARC) AND @CODTIPOPER IN (500, 501, 502, 503, 515)
	BEGIN
		UPDATE AD_PEDIDOVTEXSC SET CODPARC = @CODPARC WHERE PEDORIGINAL = @PEDORIGINAL;
		UPDATE TGFCAB SET CODPARC = @CODPARC WHERE AD_PEDORIGINAL = @PEDORIGINAL AND NUNOTA != @NUNOTA;
	END

	/*
	 * Se houver alteração no tipo de venda (CODTIPVENDA | DHTIPVENDA), atualiza outras notas pelo número unico
	 */
	IF UPDATE(CODTIPVENDA) OR UPDATE(DHTIPVENDA)
		UPDATE TGFCAB 
		SET CODTIPVENDA =	@CODTIPVENDA, 
			DHTIPVENDA =	@DHTIPVENDA 
		WHERE AD_PEDORIGINAL = @PEDORIGINAL 
		AND AD_CODREENVIO = @CODREENVIO;
END