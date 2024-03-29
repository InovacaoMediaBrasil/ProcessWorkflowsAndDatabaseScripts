USE [SANKHYA_PRODUCAO]
GO
/****** Object:  Trigger [sankhya].[TRG_INC_AD_PEDIDOSPARADOS]    Script Date: 04/10/2018 00:34:27 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*	=============================================
	Author:			Guilherme Branco Stracini
	Create date:	2018-09-04
	Description:	Adiciona os itens pendentes a tela AD_ITEMPARADO 
					quando uma expedição é adicionada a esta tela

	Author:			Guilherme Branco Stracini
	Change date:	2018-09-19
	Description:	Considera apenas a empresa 1 (Editora Inovação) na query com a TGFEST para não causar erros.

	Author:			Guilherme Branco Stracini
	Change date:	2018-10-04
	Description:	Considera os itens que já estão na AD_ITEMPARADO para verificar se o item está realmente parado.

	============================================= */
ALTER TRIGGER [sankhya].[TRG_INC_AD_PEDIDOSPARADOS]
   ON  [sankhya].[AD_PEDIDOSPARADOS]
   AFTER INSERT, UPDATE
AS 
DECLARE
	@CODPROD		INT,
	@SOLICITANTE	VARCHAR(30),
	@CODUSU			INT,
	@NUNOTA			INT,
	@QTDNEG			FLOAT,
	
	@USOPROD		CHAR(1),
	@CODKIT			INT,
	@PENDENTE		CHAR(1),
	@SEQ			INT,
	@CODVOL			VARCHAR(4)
BEGIN
	SET NOCOUNT ON;

	SELECT @SOLICITANTE = SUBSTRING(program_name,1,30) FROM MASTER.DBO.SYSPROCESSES (NOLOCK) WHERE SPID = @@SPID;
	
	SELECT	@NUNOTA =	I.NUNOTA,
			@CODUSU =	I.CODUSU
	FROM INSERTED AS I;

	IF NOT EXISTS (
		SELECT 1
		FROM sankhya.TGFITE AS I WITH (NOLOCK)
		LEFT JOIN sankhya.TGFEST AS E WITH (NOLOCK)
		ON E.CODPROD = I.CODPROD AND E.CODEMP = 1
		WHERE I.NUNOTA = @NUNOTA
		AND ISNULL((SELECT SUM(P.QTDPROD) FROM sankhya.AD_ITEMPARADO AS P WITH (NOLOCK) WHERE P.CODPROD = I.CODPROD), 0) + ISNULL(E.ESTOQUE, 0) - ISNULL(E.RESERVADO, I.QTDNEG) < 0
		AND NOT EXISTS(
			SELECT 1
			FROM sankhya.TGFICP AS C WITH (NOLOCK)
			WHERE C.CODPROD = I.CODPROD
		)
	)
	BEGIN
		RAISERROR('Não existem produtos na nota %i sem estoque!', 16, 1, @NUNOTA);
		IF (UPPER(@SOLICITANTE) LIKE 'MICROSOFT%') OR (@SOLICITANTE = 'MS SQLEM') OR (@SOLICITANTE = 'MS SQL QUERY ANALYZER')
			ROLLBACK TRANSACTION;
	END

	DECLARE cItems CURSOR FAST_FORWARD 
	FOR SELECT I.CODPROD
		FROM sankhya.TGFITE AS I WITH (NOLOCK)
		LEFT JOIN sankhya.TGFEST AS E WITH (NOLOCK)
		ON E.CODPROD = I.CODPROD AND E.CODEMP = 1
		WHERE I.NUNOTA = @NUNOTA
		AND ISNULL((SELECT SUM(P.QTDPROD) FROM sankhya.AD_ITEMPARADO AS P WITH (NOLOCK) WHERE P.CODPROD = I.CODPROD), 0) + ISNULL(E.ESTOQUE, 0) - ISNULL(E.RESERVADO, I.QTDNEG) < 0
		AND NOT EXISTS(
			SELECT 1
			FROM sankhya.TGFICP AS C WITH (NOLOCK)
			WHERE C.CODPROD = I.CODPROD
		)
		GROUP BY I.CODPROD;

	OPEN cItems;

	FETCH NEXT FROM cItems INTO @CODPROD;

	WHILE @@FETCH_STATUS = 0
	BEGIN
		INSERT INTO AD_ITEMPARADO (CODPROD, CODUSU, DTALTER, NUNOTA)
		VALUES (@CODPROD, @CODUSU, GETDATE(), @NUNOTA);

		FETCH NEXT FROM cItems INTO @CODPROD
	END;
	CLOSE cItems;
	DEALLOCATE cItems;
END
