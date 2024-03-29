USE [SANKHYA_PRODUCAO]
GO
/****** Object:  StoredProcedure [sankhya].[STP_VALIDAITEM_DESCONTO_INOVACAO]    Script Date: 02/10/2017 09:30:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*	=============================================
	Author:			Rodrigo Lacalendola
	Create date:	2017-06-06
	Description:	Controle de inserção de descontos para as TOPs 500,501 e 502
	=============================================*/
ALTER PROCEDURE [sankhya].[STP_VALIDAITEM_DESCONTO_INOVACAO]
	-- Add the parameters for the stored procedure here
	@P_NUNOTA INT, 
	@P_SEQUENCIA INT, 
	@P_SUCESSO VARCHAR OUTPUT, 
	@P_MENSAGEM VARCHAR(500) OUTPUT, 
	@P_CODUSULIB NUMERIC OUTPUT
AS
DECLARE
@CODTIPOPER INT,
@CODUSU INT,
@DESCMAX FLOAT,
@PERCDESC FLOAT
BEGIN

	SET NOCOUNT ON;
	
	/*
	 * Obtem os dados para utilização na procedure.
	 */
	SELECT	@CODTIPOPER =	CAB.CODTIPOPER,	/* Código de operação (para validar as tops específicas) */
			@CODUSU =		ITE.CODUSU,		/* Código do usuário (para validação de permissão) */
			@DESCMAX =		ISNULL(USU.AD_DESCMAX, 0),  /* Desconto máximo em porcentagem que o usuário tem permissão */
			@PERCDESC =		ISNULL(ITE.PERCDESC, 0) /* Desconto informado pelo usuário */
	FROM TGFCAB AS CAB WITH (NOLOCK)
	INNER JOIN TGFITE AS ITE WITH(NOLOCK) 
	ON CAB.NUNOTA = ITE.NUNOTA
	INNER JOIN TSIUSU AS USU WITH(NOLOCK) 
	ON USU.CODUSU = ITE.CODUSU
	WHERE CAB.NUNOTA = @P_NUNOTA
	AND ITE.SEQUENCIA = @P_SEQUENCIA;

	/* Marca como sucesso por padrão, caso não entre no if */
	SET @P_SUCESSO = 'S';

	/* 
     * Verfica se a nota é da TOP de vendas (500, 501 ou 502)
	 * e se o desconto solicitado é maior do que o permitido, se for, lança erro e faz rollback
	 */
	IF @CODTIPOPER IN (500, 501, 502) AND @PERCDESC > @DESCMAX
	BEGIN 				
			SET @P_SUCESSO = 'N';
			SET @P_MENSAGEM = 'Seu usuário não tem alçada para este desconto.';
			ROLLBACK TRANSACTION;
	END
	ELSE
		COMMIT TRANSACTION;
END