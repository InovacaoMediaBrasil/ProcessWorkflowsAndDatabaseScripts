USE [SANKHYA_PRODUCAO]
GO
/****** Object:  Trigger [sankhya].[TRG_INC_TGFVAR_INOVACAO_KIT]    Script Date: 13/06/2018 16:49:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Rafael Turra & Guilherme Branco Stracini
-- Create date: 2017-09-29
-- Description:	Faz a precificação correta dos componentes de um KIT e do KIT na TGFITE 
--				para não gerar problemas na emissão de NF-e


-- Author:		Rodrigo Lacalendola
-- Update date: 2018-05-24
-- Description:	Alterado para 04 casas decimais


-- =============================================

ALTER TRIGGER [sankhya].[TRG_INC_TGFVAR_INOVACAO_KIT] ON [sankhya].[TGFVAR] 
FOR INSERT 
AS
DECLARE
@NUNOTA				INT,
@NUNOTAORIG			INT,
@SEQUENCIA			INT,
@SEQUENCIAORIG		INT,
@CODKIT				INT,
@CODMATPRIMA		INT,
@VALOR				FLOAT,
@VALORBRINDE		FLOAT,
@QTDNEG				FLOAT,
@VALORBRINDEFINAL	FLOAT,
@CODTIPOPER			INT,
@VALORCOMPONENTE	FLOAT,
@FATOR				FLOAT,
@QTDNEGORIG			INT,
@ACUMULADODESC		FLOAT,
@TEMPA				FLOAT,
@VALORBRINDEUNIT	FLOAT,
@VALORINS			FLOAT
BEGIN

	/* 
	 * Obtém os dados da nota
	 */
	SELECT 	@NUNOTA =			I.NUNOTA,
			@NUNOTAORIG =		I.NUNOTAORIG,
			@SEQUENCIA =		I.SEQUENCIA,
			@SEQUENCIAORIG =	I.SEQUENCIAORIG
	FROM INSERTED AS I;
	
	/*
	 * Obtém o código do tipo de operação na TGFCAB
	 */
	SELECT	@CODTIPOPER = C.CODTIPOPER
	FROM sankhya.TGFCAB AS C WITH (NOLOCK)
	WHERE NUNOTA = @NUNOTA;

	/*
	 * Verifica se a nota precisa da "correção" se o NUNOTA for igual ao NUNOTAORIG
	 * e pelo código do tipo de operação, caso não precise, encerra a trigger
	 */
	IF @NUNOTA != @NUNOTAORIG
	OR @CODTIPOPER NOT IN (500, 501, 502, 503, 504, 505, 515, 520, 550, 561, 600)
		RETURN;

	/*
	 * Obtém os dados do KIT
	 */
	SELECT	@CODKIT =		I.CODPROD, 
			@QTDNEGORIG =	I.QTDNEG,
			@VALORINS =		I.VLRUNIT 
	FROM sankhya.TGFITE AS I WITH (NOLOCK)
	WHERE I.NUNOTA = @NUNOTA
	AND I.SEQUENCIA = @SEQUENCIAORIG;

	/*
	 * Obtém os dados do componente
	 */

	SELECT	@CODMATPRIMA =	I.CODPROD,
			@QTDNEG =		I.QTDNEG
	FROM sankhya.TGFITE AS I WITH (NOLOCK)
	WHERE I.NUNOTA = @NUNOTA
	AND I.SEQUENCIA = @SEQUENCIA;

	/*
	 * Se for um componente
	 */
	IF @CODMATPRIMA != @CODKIT
	BEGIN


		/*
		 * Caso seja um curso online, dentro de um KIT, verifica se está na TOP de expedição, venda ou devolução
		 * e ZERA o produto do movimento, para não atrapalhar o restante.
		 */
		 IF (SELECT CODGRUPOPROD FROM sankhya.TGFPRO WITH(NOLOCK) WHERE CODPROD = @CODMATPRIMA) != 720000
		
		/*
		 * Obtém o valor do componente para o pedido desta nota (não importa se a nota não é do pedido...)
		 * A função faz todas as validações devidas!
		 */
		 begin
			SET @VALOR = sankhya.FN_VALOR_VENDA_COMPONENTE_KIT(@CODMATPRIMA, @CODKIT, @NUNOTA, @VALORINS);
			UPDATE sankhya.TGFITE 
			SET VLRUNIT =	ROUND(@VALOR, 4), 
				VLRTOT =	ROUND(@VALOR * QTDNEG, 4) 
			WHERE NUNOTA = @NUNOTA 
			AND SEQUENCIA = @SEQUENCIA;
		 end
		 /*
		 * Zera o curso online no movimento, para não atrapalhar o restante.
		 */
		ELSE
		begin
			if  @CODTIPOPER IN (505,550,561,600)
			begin
				SET @VALOR = 0
				UPDATE sankhya.TGFITE 
				SET VLRUNIT =	0, 
					VLRTOT =	0
				WHERE NUNOTA = @NUNOTA 
				AND SEQUENCIA = @SEQUENCIA;
			end
		end
	

		/* Verificando se é um brinde */
		DECLARE @BRINDE CHAR(1)
		SELECT @BRINDE = ISNULL(AD_BRINDE,'N') FROM sankhya.TGFICP WITH(NOLOCK) WHERE CODPROD = @CODKIT AND CODMATPRIMA =  @CODMATPRIMA

		IF @BRINDE = 'S'
		BEGIN
			/* Altera o USOPROD para que seja indicado que é um brinde, e consequentemente acionar outra trigger que coloca o CFOP corretamente */
			UPDATE sankhya.TGFITE SET USOPROD = 'B' WHERE NUNOTA = @NUNOTA AND SEQUENCIA = @SEQUENCIA
		END

	END

	/*
	 * Atualiza o preço do KIT , isso é executado para cada componente infelizmente...
	 */
	SET @VALOR = sankhya.FN_VALOR_VENDA_COMPONENTE_KIT(0, @CODKIT, @NUNOTA, @VALORINS);
	UPDATE sankhya.TGFITE 
	SET VLRUNIT =	ROUND(@VALOR, 4),
		VLRTOT =	ROUND(@VALOR * QTDNEG, 4) 
	WHERE NUNOTA = @NUNOTA
	AND SEQUENCIA = @SEQUENCIAORIG AND @BRINDE = 'N'
END