USE [SANKHYA_PRODUCAO]
GO
/****** Object:  Trigger [sankhya].[TRG_DLT_TGFCAB_AD_PEDIDOVTEXSCFLUXO]    Script Date: 21/09/2018 13:21:44 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*	=============================================
	Author:			Guilherme Branco Stracini
	Create date:	2017-03-22
	Description:	Realiza o cadastro do fluxo removido na Controle de Pedidos para os pedidos que forem removidos da TGFCAB
					Os pedidos removidos da TGFCAB podem ter os seguintes comportamentos:
					Comportamento A: Pedido removido da TGFCAB - Quando: O pedido não foi confirmado
					Comportamento B: Pedido removido da TGFCAB e inserido na TGFCAB_EXC - Quando: O pedido foi confirmado
					Comportamento C: Pedido removido da TGFCAB e inserido na TGFCAN e na TGFCAB_EXC - Quando: O pedido é cancelado (e já havia sido confirmado);
					Este gatilho tem como função monitorar o comportamento A, já que os outros 2 são monitorados na TGFCAB_EXC

	Author:			Guilherme Branco Stracini
	Change date:	2017-03-28
	Description:	Verifica se o pedido é da TOP 504, se for obriga o cadastro nas tabelas de reenvio e não nas normais.

	Author:			Guilherme Branco Stracini
	Change date:	2018-09-21
	Description:	Remove o pedido da AD_PEDIDOSPARADOS e da AD_ITEMPARADO quando a nota é excluida
	============================================ */

ALTER TRIGGER [sankhya].[TRG_DLT_TGFCAB_AD_PEDIDOVTEXSCFLUXO] 
   ON  [sankhya].[TGFCAB] 
   AFTER DELETE
AS
DECLARE 
@NUNOTA INT,
@CODTIPOPER INT, 
@PEDORIGINAL INT,
@CODREENVIO INT,
@CODUSU INT,
@STATUSNOTA CHAR(1),
@ORDERID VARCHAR(100)
BEGIN
	SET NOCOUNT ON;

	/* Seleciona os dados da nota removida */
	SELECT @NUNOTA = NUNOTA,
		   @CODTIPOPER = CODTIPOPER,
		   @PEDORIGINAL = AD_PEDORIGINAL,
		   @CODREENVIO = AD_CODREENVIO,
		   @CODUSU = CODUSU,
		   @STATUSNOTA = STATUSNOTA
	FROM DELETED

	/*
	 * Remove das tabelas de pedidos/itens parados
	 */
	DELETE FROM AD_ITEMPARADO WHERE NUNOTA = @NUNOTA;
	DELETE FROM AD_PEDIDOSPARADOS WHERE NUNOTA = @NUNOTA;


	SELECT @ORDERID = ORDERID
	FROM AD_PEDIDOVTEXSC WITH (NOLOCK)
	WHERE PEDORIGINAL = @PEDORIGINAL

	/*
	 * Se  o order id for nulo é porque não existe o pedido na controle de pedidos.
	 */
	IF @ORDERID IS NULL
		RETURN;

	/* Verifica se é um reenvio e se não existe o fluxo (Removido/Cancelado) cadastrado ainda na Fluxo Reenvio para esta nota */

	IF @CODREENVIO > 0 OR @CODTIPOPER = 504
	AND NOT EXISTS (
		SELECT 1
		FROM AD_PEDIDOVTEXSCREENVIOFLUXO WITH (NOLOCK)
		WHERE NUNOTA = @NUNOTA
		AND OCORRENCIA IN ('X','C')
	)
		INSERT INTO AD_PEDIDOVTEXSCREENVIOFLUXO (CODREENVIO, CODUSU, DATA, NUNOTA, OCORRENCIA, ORDERID, PEDORIGINAL)
		VALUES (@CODREENVIO, @CODUSU, GETDATE(), @NUNOTA, 'X', @ORDERID, @PEDORIGINAL);

	/*
	 * Se não for um reenvio e não existir o fluxo (Removido/Cancelado) na fluxo, cadastra...
	 */

	ELSE IF EXISTS (
		SELECT 1
		FROM AD_PEDIDOVTEXSCFLUXO WITH (NOLOCK)
		WHERE NUNOTA = @NUNOTA	
	) AND NOT EXISTS (
		SELECT 1
		FROM AD_PEDIDOVTEXSCFLUXO WITH (NOLOCK)
		WHERE NUNOTA = @NUNOTA
		AND OCORRENCIA IN ('X','C')
	)
		INSERT INTO AD_PEDIDOVTEXSCFLUXO (CODUSU, DATA, NUNOTA, OCORRENCIA, ORDERID, PEDORIGINAL)
		VALUES(@CODUSU, GETDATE(), @NUNOTA, 'X', @ORDERID, @PEDORIGINAL);
END