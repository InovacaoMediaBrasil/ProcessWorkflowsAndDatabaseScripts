USE [SANKHYA_PRODUCAO]
GO
/****** Object:  Trigger [sankhya].[TRG_INC_TGFHPE_AD_PEDIDOVTEXSCFLUXO]    Script Date: 20/04/2018 15:14:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*	=============================================
	Author:			Guilherme Branco Stracini
	Create date:	2018-04-18
	Description:	Cadastrar o fluxo T (Troca) na tabela Fluxos - Controle de Pedidos (AD_PEDIDOVTEXSCFLUXO) ou na de Fluxos (Reenvio) - Controle de Pedidos (AD_PEDIDOVTEXSCREENVIOFLUXO)
					quando um evento dos tipos (A - alteração, E - exclusão, I - inclusão) é registrado nessa tabela (TGFHPE)

	Author:			Guilherme Branco Stracini
	Change date:	2018-04-20
	Description:	Valida se a nunota é de uma ocorrência P (pedido) para não registrar uma troca em um nota de venda (que as vezes tem o item removido e recolocado para aprovar a NF-e)
	============================================= */
ALTER TRIGGER [sankhya].[TRG_INC_TGFHPE_AD_PEDIDOVTEXSCFLUXO]
   ON  [sankhya].[TGFHPE]
   AFTER INSERT
AS 
DECLARE
@NUNOTA			INT,
@PEDORIGINAL	INT,
@ORDERID		VARCHAR(100),
@CODREENVIO		INT,
@DATA			DATETIME,
@CODUSU			INT,
@OCORRENCIA		CHAR
BEGIN
	SET NOCOUNT ON;

	/*
	 * Código da ocorrência
 	 */
	SET @OCORRENCIA = 'A';

	/*
	 * Obtém os dados básicos da nota
	 */
	SELECT	@NUNOTA =		I.NUNOTA,
			@CODUSU =		I.CODUSU,
			@DATA =			I.DHALTER,
			@PEDORIGINAL =	P.PEDORIGINAL,
			@ORDERID =		P.ORDERID,
			@CODREENVIO =	C.AD_CODREENVIO
	FROM INSERTED AS I
	INNER JOIN TGFCAB AS C WITH (NOLOCK)
	ON I.NUNOTA = C.NUNOTA
	INNER JOIN AD_PEDIDOVTEXSC AS P WITH (NOLOCK)
	ON C.AD_PEDORIGINAL = P.PEDORIGINAL
	WHERE EVENTO != 'C';


	/*
	 * Verifica se o pedido original ou o order id são nulos
	 * caso um dos dois seja nulo, o pedido não existe na controle e encerra o gatilho
	 */

	 IF @PEDORIGINAL IS NULL 
	 OR @ORDERID IS NULL
		RETURN;

	/*
	 * Se não for um pedido (ocorrência P) e encerra a trigger.
	 * Evita de marcar o fluxo de troca em notas (que as vezes tem os itens removidos e inseridos novamente para validação)
	 */
	IF NOT EXISTS (SELECT 1 FROM AD_PEDIDOVTEXSCFLUXO WITH (NOLOCK) WHERE NUNOTA = @NUNOTA AND OCORRENCIA = 'P')
	AND NOT EXISTS (SELECT 1 FROM AD_PEDIDOVTEXSCREENVIOFLUXO WITH (NOLOCK) WHERE NUNOTA = @NUNOTA AND OCORRENCIA = 'P')
		RETURN;

	/*
	 * Se for reenvio
	 */
	IF @CODREENVIO >= 1
	BEGIN
		/*
		 * Caso já exista o fluxo, deleta ele
		 */
		IF EXISTS (
			SELECT 1 
			FROM AD_PEDIDOVTEXSCREENVIOFLUXO WITH (NOLOCK)
			WHERE OCORRENCIA = @OCORRENCIA
			AND NUNOTA = @NUNOTA
		)
			DELETE FROM AD_PEDIDOVTEXSCREENVIOFLUXO
			WHERE OCORRENCIA = @OCORRENCIA
			AND NUNOTA = @NUNOTA;
		/*
		 * Faz a inserção do fluxo
		 */
		INSERT INTO AD_PEDIDOVTEXSCREENVIOFLUXO (CODREENVIO, CODUSU, DATA, NUNOTA, OCORRENCIA, ORDERID, PEDORIGINAL)
		VALUES (@CODREENVIO, @CODUSU, @DATA, @NUNOTA, @OCORRENCIA, @ORDERID, @PEDORIGINAL);
		
		/*
		 * Encerra o gatilho
		 */
		RETURN;
	END
	
	/*
	 * Verifica se o fluxo existe na tabela de fluxos, caso exista apaga
	 */
	IF EXISTS (
		SELECT 1 
		FROM AD_PEDIDOVTEXSCFLUXO WITH (NOLOCK)
		WHERE OCORRENCIA = @OCORRENCIA
		AND NUNOTA = @NUNOTA
	)
		DELETE FROM AD_PEDIDOVTEXSCFLUXO
		WHERE OCORRENCIA = @OCORRENCIA
		AND NUNOTA = @NUNOTA;
	
	/*
	 * Faz a inserção do fluxo
	 */
	INSERT INTO AD_PEDIDOVTEXSCFLUXO (CODUSU, DATA, NUNOTA, OCORRENCIA, ORDERID, PEDORIGINAL)
	VALUES (@CODUSU, @DATA, @NUNOTA, @OCORRENCIA, @ORDERID, @PEDORIGINAL);
END
