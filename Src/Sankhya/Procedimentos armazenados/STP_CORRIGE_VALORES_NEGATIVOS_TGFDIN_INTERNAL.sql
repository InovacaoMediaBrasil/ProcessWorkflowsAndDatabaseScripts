USE [SANKHYA_PRODUCAO]
GO
/****** Object:  StoredProcedure [sankhya].[STP_CORRIGE_VALORES_NEGATIVOS_TGFDIN_INTERNAL]    Script Date: 20/03/2018 16:06:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*	=============================================
	Author:			Rodrigo Lacalendola
	Create date:	2016-12-03
	Description:	Corrige impostos negativos na nota das TOPs 550, 561 e 600

	Author:			Guilherme Branco Stracini
	Change date:	2017-04-17
	Description:	Proceudure extraida da STP_CORRIGE_VALORES_NEGATIVOS_TGFDIN para permitir correção (chamada) externa ao Sankhya (manual / Integração Service)

	Author:			Guilherme Branco Stracin
	Change date:	2018-03-20
	Description:	Cadastra na TSIAVI o código do usuário também.
	=============================================*/
ALTER PROCEDURE [sankhya].[STP_CORRIGE_VALORES_NEGATIVOS_TGFDIN_INTERNAL] 
	-- Add the parameters for the stored procedure here
	@NUNOTA INT,
	@CODUSU INT
AS
BEGIN	
	SET NOCOUNT ON;

	/*
	 * Verifica se a nota pertence a uma TOP liberada para correção (550, 561, 600)
	 */

	IF NOT EXISTS (
		SELECT 1 
		FROM TGFCAB WITH (NOLOCK) 
		WHERE NUNOTA = @NUNOTA
		AND CODTIPOPER IN (550, 561, 562, 600))
			RAISERROR('A nota %i não pertence as TOPs (550, 561, 562 e 600) liberadas para correção de imposto negativo.',16,1, @NUNOTA);
	/*
	 * Realiza a correção na TGFDIN.
	 */

	UPDATE	DIN SET
			BASE =			ITE.VLRTOT-ITE.VLRDESC,
			BASERED =		ITE.VLRTOT-ITE.VLRDESC,
			BASEDIFAL =		ITE.VLRTOT-ITE.VLRDESC,
			VALOR =			((ITE.VLRTOT-ITE.VLRDESC)*ALIQUOTA)/100,
			VLRDIFALDEST =	((((ITE.VLRTOT-ITE.VLRDESC)*(ALIQINTDEST-ALIQUOTA))/100)*PERCPARTDIFAL)/100,
			VLRDIFALREM =	((((ITE.VLRTOT-ITE.VLRDESC)*(ALIQINTDEST-ALIQUOTA))/100)*(100-PERCPARTDIFAL))/100
	FROM TGFDIN AS DIN WITH (NOLOCK)
	INNER JOIN TGFITE AS ITE WITH (NOLOCK) 
	ON ITE.NUNOTA = DIN.NUNOTA 
	AND ITE.SEQUENCIA = DIN.SEQUENCIA
	WHERE DIN.NUNOTA = @NUNOTA
	AND (DIN.BASE <= 0 OR DIN.BASEDIFAL <= 0);

	INSERT INTO TGFACT (NUNOTA, SEQUENCIA, DHOCOR, HRACT, OCORRENCIAS, DIGITADO, CODUSU) 
	VALUES (@NUNOTA, 0, CAST(GETDATE() AS DATE), CAST(DATEPART(HOUR, GETDATE()) AS VARCHAR(2)) + RIGHT('0' + CAST(DATEPART(MINUTE, GETDATE()) AS VARCHAR(2)), 2) + RIGHT('0' + CAST(DATEPART(SECOND, GETDATE()) AS VARCHAR(2)), 2) ,'Executado procedimento de correção de imposto negativo','N', @CODUSU);
END
