-- ================================================
-- Template generated from Template Explorer using:
-- Create Trigger (New Menu).SQL
--
-- Use the Specify Values for Template Parameters 
-- command (Ctrl-Shift-M) to fill in the parameter 
-- values below.
--
-- See additional Create Trigger templates for more
-- examples of different Trigger statements.
--
-- This block of comments will not be included in
-- the definition of the function.
-- ================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Guilherme Branco Stracini
-- Create date: 10/10/2013
-- Description:	Restringe o campo prefixo para 2 caracteres e sem valores duplicados
-- =============================================
CREATE TRIGGER sankhya.TRG_INC_UPD_AD_LOJA 
   ON  sankhya.AD_LOJA 
   AFTER INSERT,UPDATE
AS 
DECLARE
@CODLOJA INT,
@PREFIXO CHAR(100),
@SOLICITANTE CHAR(30)
BEGIN
	SET NOCOUNT ON;
	SELECT @CODLOJA = CODLOJA, @PREFIXO = PREFIXO FROM INSERTED;
	SELECT @SOLICITANTE = SUBSTRING(program_name,1,30) FROM MASTER.DBO.SYSPROCESSES (NOLOCK) WHERE SPID = @@SPID;
	
	IF (LEN(@PREFIXO) <> 2)
	BEGIN 
		RAISERROR('Campo Prefixo para Referência deve ter exatamente 2 caracteres.', 16, 1);
		IF (UPPER(@SOLICITANTE) LIKE 'MICROSOFT%') OR (@SOLICITANTE = 'MS SQLEM') OR (@SOLICITANTE = 'MS SQL QUERY ANALYZER')
			ROLLBACK TRANSACTION;
	END	
	IF (EXISTS(SELECT 1 FROM AD_LOJA WHERE PREFIXO = @PREFIXO AND CODLOJA <> @CODLOJA))
	BEGIN
		RAISERROR('Já existe outra Loja com este Prefixo para Referência.', 16, 1);
		IF (UPPER(@SOLICITANTE) LIKE 'MICROSOFT%') OR (@SOLICITANTE = 'MS SQLEM') OR (@SOLICITANTE = 'MS SQL QUERY ANALYZER')
			ROLLBACK TRANSACTION;
	END
	
END
GO
