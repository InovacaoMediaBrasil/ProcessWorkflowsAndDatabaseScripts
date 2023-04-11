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
-- Create date: 28/10/2013
-- Description:	Impede a exclusão de uma loja
-- =============================================
CREATE TRIGGER sankhya.TRG_DLT_AD_LOJA 
   ON  sankhya.AD_LOJA 
   AFTER DELETE
AS 
DECLARE
@SOLICITANTE CHAR(30)
BEGIN
	SET NOCOUNT ON;
	BEGIN
		SELECT @SOLICITANTE = SUBSTRING(program_name,1,30) FROM MASTER.DBO.SYSPROCESSES (NOLOCK) WHERE SPID = @@SPID;
		RAISERROR('Não é permitido remover uma Loja.', 16, 1);	
		IF (UPPER(@SOLICITANTE) LIKE 'MICROSOFT%') OR (@SOLICITANTE = 'MS SQLEM') OR (@SOLICITANTE = 'MS SQL QUERY ANALYZER')
			ROLLBACK TRANSACTION;
	END	
END
GO
