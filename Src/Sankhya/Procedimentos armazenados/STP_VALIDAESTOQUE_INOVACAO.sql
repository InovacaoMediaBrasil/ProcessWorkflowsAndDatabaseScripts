USE [SANKHYA_PRODUCAO]
GO
/****** Object:  StoredProcedure [sankhya].[STP_VALIDAESTOQUE_INOVACAO]    Script Date: 25/04/2018 17:45:24 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*	=============================================	
	Author:			Decio B. Júnior
	Create date:	2014-12-04
	Description:	Controle de inserção de itens no Sankhya-W
	
	Author:			Guilherme Branco Stracini
	Change date:	2017-02-09
	Description:	Atualizado para validar o grupo de usuário (TI - 1) e 
					não mais o usuário 67 (integração  Service)

	Author:			Rodrigo Lacalendola
	Change date:	2017-07-19
	Description:	Controle de ALTERAÇÃO de itens no Sankhya-W
					Atualizado para validar quando é apenas um UPDATE e não está sendo alterado a quantidade 
					negociada do item, apenas alteração de preço/desconto/etc.
	=============================================*/
ALTER PROCEDURE [sankhya].[STP_VALIDAESTOQUE_INOVACAO]
	/* Valida a inserção de algum item na TOP. 
	   Se o mesmo permite estoque negativo, libera.
	   Caso não permita, irá liberar somente se o saldo em estoque for maior que zero.
	   Se a inserção estiver sendo feita pelo usuário do TI (Código do grupo 1), libera de qualquer forma.
	*/
	@P_NUNOTA INT, @P_SEQUENCIA INT, @P_SUCESSO VARCHAR OUTPUT, @P_MENSAGEM VARCHAR(250) output, @P_CODUSULIB NUMERIC output
AS
BEGIN
     SET NOCOUNT ON;
	 DECLARE 
		@CODPROD AS INT,	
		@P_ESTNEG AS CHAR(1),
		@SALDO AS DECIMAL(18,5),
		@QTDNEG AS DECIMAL(18,5),
		@CODGRUPO AS INT,
		@USOPROD AS CHAR(1),
		@DHALTERHPE DATETIME,
		@DTALTERITE DATETIME,
		@QTDNEGHPE FLOAT;

	 
	SELECT	@CODPROD =	ITE.CODPROD, 
			@P_ESTNEG =	PRO.AD_PESTNEG,
			@SALDO =	sankhya.FN_ESTOQUE_INOVACAO(ITE.CODPROD),
			@QTDNEG =	CAST(ITE.QTDNEG AS DECIMAL(18,5)),
			@USOPROD =	ITE.USOPROD,
			@CODGRUPO = USU.CODGRUPO,
			@DTALTERITE = ITE.DTALTER,
			@DHALTERHPE = HPE.DHALTER,
			@QTDNEGHPE = HPE.QTDNEG
	FROM TGFITE AS ITE WITH(NOLOCK)
	INNER JOIN TGFPRO AS PRO WITH(NOLOCK) ON PRO.CODPROD = ITE.CODPROD	
	INNER JOIN TSIUSU AS USU WITH(NOLOCK) ON USU.CODUSU = ITE.CODUSU
	LEFT JOIN TGFHPE AS HPE WITH(nOLOCK) ON HPE.CODPROD = ITE.CODPROD AND HPE.SEQUENCIA = ITE.SEQUENCIA AND HPE.EVENTO = 'C'
	WHERE ITE.NUNOTA = @P_NUNOTA 
	AND ITE.SEQUENCIA = @P_SEQUENCIA


	/* Primeira inserção - não existe histórico anterior */
	IF (@DHALTERHPE IS NULL)
	BEGIN
	
		/* Verifica se a quantidade inserida é maior que o saldo disponível quando é um KIT ou AVULSO */
		IF	((@QTDNEG > (@SALDO + @QTDNEG)) AND @USOPROD = 'R'  AND @CODGRUPO != 1)
		--AND (@P_ESTNEG = 'N' OR @P_ESTNEG IS NULL)
		BEGIN
			SET @P_SUCESSO = 'N'
			SET @P_MENSAGEM = 'Produto ' + CAST(@CODPROD  AS VARCHAR) + ' não possui saldo suficiente (Disponível - Reservado) em estoque e não permite estoque negativo. Quantidade disponível: ' + RTRIM(CAST(@SALDO + @QTDNEG AS VARCHAR(10))) + '. Qtd inserida: ' + RTRIM(CAST(@QTDNEG AS VARCHAR(10)))
		END

		/* Caso tenha estoque ou seja matéria prima de kit ou brinde */
		ELSE 
			SET @P_SUCESSO = 'S'
	END


	/* Alteração - já existe histórico anterior e a data de alteração da ITE é maior que a data de confirmação do pedido marcada na HPE */
	IF (@DHALTERHPE IS NOT NULL AND @DTALTERITE > @DHALTERHPE)
	BEGIN
	

		/* Verifica se a quantidade alterada é maior que o saldo disponível quando é um KIT ou AVULSO */
		IF	(@QTDNEG != @QTDNEGHPE AND ((@QTDNEG-@QTDNEGHPE) > (@SALDO + (@QTDNEG-@QTDNEGHPE))) AND @USOPROD = 'R' AND @CODGRUPO != 1)
		--AND (@P_ESTNEG = 'N' OR @P_ESTNEG IS NULL)
		BEGIN
			SET @P_SUCESSO = 'N'
			SET @P_MENSAGEM = 'Produto ' + CAST(@CODPROD  AS VARCHAR) + ' não possui saldo suficiente (Disponível - Reservado) em estoque e não permite estoque negativo. Quantidade disponível: ' + RTRIM(CAST(@SALDO + @QTDNEG AS VARCHAR(10))) + '. Qtd alterada: ' + RTRIM(CAST((@QTDNEG-@QTDNEGHPE) AS VARCHAR(10)))
		END

		/* Caso tenha estoque ou seja matéria prima de kit ou brinde */
		ELSE 
			SET @P_SUCESSO = 'S'
	END

END