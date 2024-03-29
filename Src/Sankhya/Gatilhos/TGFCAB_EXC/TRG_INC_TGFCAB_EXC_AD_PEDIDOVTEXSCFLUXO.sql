USE [SANKHYA_PRODUCAO]
GO
/****** Object:  Trigger [sankhya].[TRG_INC_TGFCAB_EXC_AD_PEDIDOVTEXSCFLUXO]    Script Date: 11/04/2018 13:16:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* =============================================
	Author:			Guilherme Branco Stracini
	Create date:	2014-02-25 25/02/2014
	Description:	Efetua o cadastro do fluxo do pedido cancelado ou removido na tela de fluxos na controle de pedidos (pedido normal & reenvio)

	Author:			Guilherme Branco Stracini
	Change date:	2016-12-26
	Description:	Verifica o fluxo (Removido/Cancelado) se já não existe para aquela nota, caso exista, remove-o primeiro e cadatra o valor atualizado.

	Author:			Guilherme Branco Stracini
	Change date:	2017-03-22
	Description:	Documentando e efetuada algumas melhorias

	Author:			Guilherme Branco Stracini
	Change date:	2018-03-28
	Description:	Marca o envio na AD_CPENVIOS como cancelado ao adicionar uma nota que possui envio na TGFCAB_EXC 
					se o status do envio for não iniciado (N) ou se o status for em transporte (T) ou entregue (E).
					Apaga também os monitoramentos na AD_CPENVIOSMONITORAMENTOS

	Author:			Guilherme Branco Stracini
	Change date:	2018-04-11
	Description:	Cadastra o pedido original e código de reenvio na TGFCAB_EXC
   =============================================*/
ALTER TRIGGER [sankhya].[TRG_INC_TGFCAB_EXC_AD_PEDIDOVTEXSCFLUXO] 
   ON  [sankhya].[TGFCAB_EXC] 
   AFTER INSERT
AS 
DECLARE 
@NUNOTA INT,
@PEDORIGINAL INT,
@ORDERID VARCHAR(100),
@OCORRENCIA VARCHAR(1),
@CODREENVIO INT,
@CODUSU INT
BEGIN

	SET NOCOUNT ON;

	/*
	 * Obtem o NUNOTA e CODUSU da nota removida
	 */
	SELECT @NUNOTA =	I.NUNOTA, 
		   @CODUSU =	I.CODUSU
	FROM INSERTED AS I

	/*
	 * Obtém o PEDORIGINAL e o ORDERID da nota removida na Fluxos
	 */
	SELECT @PEDORIGINAL =	PEDORIGINAL, 
		   @ORDERID =		ORDERID
	FROM AD_PEDIDOVTEXSCFLUXO WITH (NOLOCK) 
	WHERE NUNOTA = @NUNOTA;
	
	/*
	 * Se não localizar na Fluxos procura na Fluxos reenvios
	 */
	 IF @PEDORIGINAL IS NULL
		SELECT	@PEDORIGINAL =	PEDORIGINAL,
				@ORDERID =		ORDERID,
				@CODREENVIO =	CODREENVIO
		FROM AD_PEDIDOVTEXSCREENVIOFLUXO WITH (NOLOCK)
		WHERE NUNOTA = @NUNOTA;

	/*
	 * Se o pedido original e/ou order id forem nulos o pedido não existe na Controle de Pedidos e nem na Controle de pedidos Reeenvios
	 * então encerra a trigger
	 */

	 IF @ORDERID IS NULL
		RETURN;
	
	/*
	 * Atualiza a nota com o AD_PEDORIGINAL e AD_CODREENVIO
	 */
	 UPDATE TGFCAB_EXC 
	 SET	AD_PEDORIGINAL =	@PEDORIGINAL,
			AD_CODREENVIO =		ISNULL(@CODREENVIO, 0)
	 WHERE NUNOTA = @NUNOTA;

	/*
	 * Informa que a ocorrência é X (removido) e verifica se a nota existe na TGFCAN (cancelamento), 
	 * caso exista, a ocorrência é C (Cancelado)
	 */

	SET @OCORRENCIA = 'X';
	IF EXISTS(SELECT 1 FROM sankhya.TGFCAN WITH(NOLOCK) WHERE NUNOTA = @NUNOTA)
		SET @OCORRENCIA = 'C';
	
	/*
	 *	Verifica se não é bonificado
	 */
	IF @CODREENVIO IS NULL
	BEGIN
		/* Se já existir o fluxo, então remove ele*/
		IF EXISTS(
			SELECT 1 
			FROM AD_PEDIDOVTEXSCFLUXO WITH (NOLOCK) 
			WHERE NUNOTA = @NUNOTA
			AND OCORRENCIA IN ('C','X'))

			DELETE FROM AD_PEDIDOVTEXSCFLUXO
			WHERE NUNOTA = @NUNOTA
			AND OCORRENCIA IN ('C','X');

		/* Insere o fluxo atualizado */
		INSERT INTO AD_PEDIDOVTEXSCFLUXO (DATA, NUNOTA, OCORRENCIA, CODUSU, ORDERID, PEDORIGINAL)
		VALUES (GETDATE(), @NUNOTA, @OCORRENCIA, @CODUSU, @ORDERID, @PEDORIGINAL);
	END

	/*
	 * Se for bonificado
	 */

	ELSE 
	BEGIN
		/* Se já existir o fluxo, remove-o*/
		IF EXISTS(
			SELECT 1 
			FROM AD_PEDIDOVTEXSCREENVIOFLUXO WITH (NOLOCK) 
			WHERE NUNOTA = @NUNOTA
			AND CODREENVIO = @CODREENVIO
			AND OCORRENCIA IN ('C','X'))

			DELETE FROM AD_PEDIDOVTEXSCREENVIOFLUXO
			WHERE NUNOTA = @NUNOTA
			AND CODREENVIO = @CODREENVIO
			AND OCORRENCIA IN ('C','X');

		/* Insere o fluxo atualizado */
		INSERT INTO AD_PEDIDOVTEXSCREENVIOFLUXO (CODREENVIO, DATA, NUNOTA, OCORRENCIA, CODUSU, ORDERID, PEDORIGINAL)
		VALUES (@CODREENVIO, GETDATE(), @NUNOTA, @OCORRENCIA, @CODUSU, @ORDERID, @PEDORIGINAL);
	END

	/*
	 * Se existir um código de rastreio (AD_CPENIVOS) para essa nota (então é uma NF-e e será gerada outra no lugar), 
	 * e ele estiver no status N (não iniciado), T (transporte), E (entregue) marca ele como C (cancelado),
	 * assim quando uma nova nota for gerada (já que essa nota cancelada é uma NF-e) irá reutilizar o código de envio (que possivelmente já foi até enviado pro cliente)
	 */

	IF EXISTS(SELECT 1 FROM AD_CPENVIOS WITH (NOLOCK) WHERE NUNOTA = @NUNOTA AND STATUS IN ('N', 'T', 'E'))
	BEGIN
		UPDATE AD_CPENVIOS SET STATUS = 'C' WHERE NUNOTA = @NUNOTA;
		DELETE FROM AD_CPENVIOSMONITORAMENTOS WHERE NUNOTA = @NUNOTA;
	END
END
