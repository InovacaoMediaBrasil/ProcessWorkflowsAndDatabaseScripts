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
-- Create date: 04/01/2013
-- Description:	Atualiza valor de CONVERSAO apos update
-- =============================================
CREATE TRIGGER sankhya.TRG_UPD_AD_AGENDAMIDIAS
	ON sankhya.AD_AGENDAMIDIAS
	AFTER UPDATE
	AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	IF UPDATE(NROLIGACOES) OR UPDATE(NROPEDIDOS)
	BEGIN
		UPDATE A SET CONVERSAO = CASE WHEN (I.NROLIGACOES = 0 OR I.NROPEDIDOS = 0) THEN 0 ELSE ((I.NROPEDIDOS / I.NROLIGACOES)*100) END
		FROM INSERTED I 
		INNER JOIN AD_AGENDAMIDIAS A
		ON I.CODIGO = A.CODIGO
	END
    -- Insert statements for trigger here
END
GO
